# frozen_string_literal: true

# 解答プログラム（エージェントが書いた信頼できないコード）を隔離して実行します。
#
# - Linux: bubblewrap (bwrap)。Ruby の実行に必要な場所だけを読み取り専用で見せ、
#   /tmp とホームは空の tmpfs にする。リポジトリはマウントしない。ネットワークは切る。
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
      # 解答ファイルは実行用の一時ディレクトリへ移す。サンドボックスはそこだけを書き込み可能にする。
      ruby_args = stage_args(ruby_args, tmp)
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

  # -e 以外のスクリプト引数を tmp の中へコピーする。元のパスがリポジトリ内でも、
  # サンドボックスからそのディレクトリを見せずに実行できる。
  def stage_args(ruby_args, tmp)
    return ruby_args if ruby_args.first == "-e"

    ruby = File.realpath(RbConfig.ruby)
    ruby_args.map do |arg|
      next arg unless arg.is_a?(String) && arg.start_with?("/") && File.file?(arg)

      real = File.realpath(arg)
      next arg if real == ruby || real.start_with?(tmp + "/")

      dest = File.join(tmp, "answer.rb")
      dest = File.join(tmp, "prog-#{File.basename(real)}") if File.exist?(dest)
      FileUtils.cp(real, dest)
      File.chmod(0o644, dest)
      dest
    end
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
      [env, *bwrap_argv(tmp), "--chdir", tmp, *cmd]
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

  # ホストの / は丸ごと見せない。Ruby と動的リンカに必要な場所だけを読み取り専用で渡し、
  # /tmp とホームは空の tmpfs にする。解答は tmp（実行用ディレクトリ）だけから読める。
  def bwrap_argv(tmp)
    args = %w[bwrap --unshare-all --die-with-parent --new-session --dev /dev --proc /proc]
    mounted = []
    # /usr を先に束ねてから、/bin や /lib が usr へのシンボリックリンクでも辿れるようにする。
    %w[/usr /lib /lib64 /bin].each { add_system_mount(args, mounted, _1) }
    made = []
    ruby_runtime_dirs.each { |dir| add_ro_bind_with_parents(args, mounted, made, dir) unless covered?(dir, mounted) }
    %w[/tmp /home /root].each { |path| args += ["--tmpfs", path] if safe_tmpfs?(path, mounted) }
    home = ENV["HOME"]
    if home && File.directory?(home) && !masked_by_empty_home?(File.realpath(home))
      args += ["--tmpfs", File.realpath(home)] if safe_tmpfs?(home, mounted)
    end
    # 読み取り専用で見せた木の中にリポジトリがあるときだけ、空の tmpfs で覆う。
    # 見せていないパスに tmpfs を足すと、無いディレクトリを作ってしまう。
    hidden_paths.each do |path|
      next unless safe_tmpfs?(path, mounted)
      next unless mounted.any? { |base| path == base || path.start_with?(base + "/") }

      args += ["--tmpfs", path]
    end
    # /tmp を tmpfs にしたあとで、実行用ディレクトリだけ書き戻す。
    args += ["--bind", tmp, tmp]
    args
  end

  def ruby_runtime_dirs
    keys = %w[prefix rubylibdir rubyarchdir libdir]
    dirs = keys.filter_map { |key| RbConfig::CONFIG[key] }.select { File.directory?(_1) }
    dirs << File.dirname(File.realpath(RbConfig.ruby))
    dirs.map { File.realpath(_1) }.uniq
  end

  def add_system_mount(args, mounted, path)
    return unless File.exist?(path)

    if File.symlink?(path)
      args << "--symlink" << File.readlink(path) << path
    else
      args << "--ro-bind" << path << path
    end
    mounted << File.realpath(path)
  end

  # /usr の外（rbenv や /opt/ruby など）にあるランタイムを、親ディレクトリを空で作りながら載せる。
  def add_ro_bind_with_parents(args, mounted, made, dir)
    real = File.realpath(dir)
    return if covered?(real, mounted)

    parts = real.split("/").reject(&:empty?)
    acc = ""
    parts.each_with_index do |part, i|
      acc = "#{acc}/#{part}"
      if i == parts.length - 1
        args << "--ro-bind" << real << acc
        mounted << real
      elsif !made.include?(acc) && !covered?(acc, mounted)
        args << "--dir" << acc
        made << acc
      end
    end
  end

  def covered?(path, mounted)
    mounted.any? { |base| path == base || path.start_with?(base + "/") }
  end

  # すでに見せている Ruby 本体を tmpfs で隠さない。
  def safe_tmpfs?(path, mounted)
    return false if path.nil? || path.empty? || path == "/"

    real = File.exist?(path) ? File.realpath(path) : path
    return false if real == "/"
    return false if mounted.any? { |base| base == real || base.start_with?(real + "/") }

    true
  end

  def masked_by_empty_home?(path)
    %w[/home /root /tmp].any? { |mask| path == mask || path.start_with?(mask + "/") }
  end
end
