# frozen_string_literal: true

# 解答プログラム（エージェントが書いた信頼できないコード）を隔離して実行します。
#
# - Linux: bubblewrap (bwrap)。リポジトリと非公開テストを空の tmpfs で隠し、ネットワークを切ります。
# - macOS: sandbox-exec。リポジトリと非公開テストの読み書きを禁止し、ネットワークを切ります。
#
# 環境変数 GOLF_SANDBOX で切り替えます。
#   auto (既定) : 使えるサンドボックスを使う。どちらも無ければエラーにする（黙って素で動かさない）
#   off         : 隔離しない（人間が手元で試すとき用）

require "open3"
require "rbconfig"
require "tmpdir"
require "fileutils"

module GolfSandbox
  ROOT = File.expand_path("..", __dir__)
  CHILD_ENV = { "LANG" => "C.UTF-8", "LC_ALL" => "C.UTF-8" }.freeze
  # 標準出力・標準エラーそれぞれ。超えたらプロセスを止めて :output_limit を返す。
  OUTPUT_LIMIT = 4 * 1024 * 1024

  module_function

  def private_dir = ENV.fetch("GOLF_PRIVATE_DIR", File.join(ROOT, "private"))

  # 隠すべきディレクトリ（実在するものだけ、実パスで）
  def hidden_paths
    [ROOT, private_dir].select { File.exist?(_1) }.map { File.realpath(_1) }.uniq
  end

  def mode
    m = ENV.fetch("GOLF_SANDBOX", "auto")
    return :off if m == "off"
    return :bwrap if which("bwrap")
    return :seatbelt if which("sandbox-exec")

    raise "サンドボックスが見つかりません。Linux は bubblewrap、macOS は sandbox-exec が必要です（隔離せずに動かすなら GOLF_SANDBOX=off）"
  end

  def which(cmd) = ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).map { File.join(_1, cmd) }.find { File.executable?(_1) }

  # ruby_args を隔離して実行し、[status, stdout, stderr] を返す。
  # status は :ok / :runtime_error / :timeout / :output_limit
  # 制限時間は起動から標準入力の書き込み、プロセスの終了までを覆う。
  # 大きな標準入力を子が読まないまま眠ると、書き込みがパイプでブロックするため、
  # 書き込みが終わってから計時すると制限が効かない。
  def run(ruby_args, input, time_limit:)
    Dir.mktmpdir("golf-run") do |tmp|
      tmp = File.realpath(tmp)
      cmd = wrap([RbConfig.ruby, *ruby_args], tmp)
      deadline = monotonic + time_limit
      Open3.popen3(*cmd, chdir: tmp, pgroup: true, unsetenv_others: true) do |stdin, stdout, stderr, th|
        limited = false
        limit_lock = Mutex.new
        on_limit = lambda do
          first = false
          limit_lock.synchronize { first = !limited; limited = true }
          kill_group(th.pid) if first
        end
        out = Thread.new { read_capped(stdout, on_limit) }
        err = Thread.new { read_capped(stderr, on_limit) }
        writer = Thread.new { write_stdin(stdin, input) }
        remaining = deadline - monotonic
        timed_out = !th.join(remaining.positive? ? remaining : 0)
        if timed_out
          kill_group(th.pid)
          th.join
        end
        writer.join
        hit_limit = limit_lock.synchronize { limited }
        status = if hit_limit
          :output_limit
        elsif timed_out
          :timeout
        else
          th.value.success? ? :ok : :runtime_error
        end
        [status, out.value, err.value]
      end
    end
  end

  def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # 上限を超えた分は捨て、on_limit を一度呼ぶ。呼び出し側がプロセスを止める。
  def read_capped(io, on_limit)
    buf = +"".b
    io.binmode
    while (chunk = io.read(65_536))
      buf << chunk
      next if buf.bytesize <= OUTPUT_LIMIT

      buf = buf.byteslice(0, OUTPUT_LIMIT)
      on_limit.call
      break
    end
    buf
  rescue IOError
    buf
  end

  def write_stdin(stdin, input)
    stdin.write(input.to_s)
  rescue Errno::EPIPE, Errno::ECONNRESET, IOError
    nil
  ensure
    begin
      stdin.close
    rescue IOError
      nil
    end
  end

  def kill_group(pid)
    Process.kill("KILL", -pid)
  rescue Errno::ESRCH, Errno::EPERM
    Process.kill("KILL", pid)
  rescue Errno::ESRCH, Errno::EPERM
    nil
  end

  # 解答ファイルを一時ディレクトリにコピーしてから実行する（元の場所がリポジトリ内でも動くように）
  def run_file(path, input, time_limit:)
    src = File.binread(path)
    Dir.mktmpdir("golf-src") do |dir|
      copy = File.join(File.realpath(dir), "answer.rb")
      File.binwrite(copy, src)
      FileUtils.chmod(0o644, copy)
      FileUtils.chmod(0o755, dir)
      run([copy], input, time_limit:)
    end
  end

  def wrap(cmd, tmp)
    env = CHILD_ENV.merge("PATH" => "/usr/local/bin:/usr/bin:/bin", "HOME" => tmp)
    case mode
    when :off
      [env, *cmd]
    when :bwrap
      args = %w[bwrap --ro-bind / / --dev /dev --proc /proc --unshare-all --die-with-parent --new-session]
      hidden_paths.each { args += ["--tmpfs", _1] }
      args += ["--bind", tmp, tmp]
      # 解答ファイルのコピーが置かれた場所（/tmp 配下）は読めるようにしておく
      [env, *args, "--chdir", tmp, *cmd]
    when :seatbelt
      deny = hidden_paths.map { %((subpath "#{_1}")) }.join(" ")
      profile = <<~SB
        (version 1)
        (allow default)
        (deny network*)
        (deny file-read* file-write* #{deny})
      SB
      [env, "sandbox-exec", "-p", profile, *cmd]
    end
  end
end
