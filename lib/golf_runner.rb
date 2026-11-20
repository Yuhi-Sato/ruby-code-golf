# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8

# 1問を隔離した Claude Code に解かせ、運営者向けの bin/judge --json で回収する。
#
#   bin/evaluate runs/specs/01.yml
#   bin/evaluate --problem 01
#   bin/evaluate --all [--jobs N]
#
# 実行ディレクトリはリポジトリの外（既定: ~/golf-runs/runs/<時刻>-<問題>/）。
# 認証は CLAUDE_CODE_OAUTH_TOKEN（claude setup-token）。無ければ起動しない。

require "fileutils"
require "json"
require "open3"
require "rbconfig"
require "thread"
require "yaml"

module GolfRunner
  ROOT = File.expand_path("..", __dir__)
  EXPORT = File.join(ROOT, "tools", "export_workspace.rb")
  JUDGE = File.join(ROOT, "bin", "judge")
  DEFAULT_PROMPT = "CONDITIONS.md と PROBLEM.md を読んで、judge に通る最短の解答を answer.rb に書いて"
  DEFAULT_TIME_LIMIT = "30m"
  DEFAULT_SILENCE_LIMIT = "5m"
  CREDENTIALS_NAME = ".credentials.json"

  module_function

  def main(argv)
    opts = parse_args(argv)
    if opts[:help]
      $stdout.puts(usage)
      return 0
    end
    prepare!(opts)
    if opts[:all]
      run_all(opts)
    else
      spec = effective_spec(opts)
      abort "problem が必要です（仕様ファイルか --problem）" if spec["problem"].to_s.empty?
      outcome = run_one(spec, opts)
      outcome[:ok] ? 0 : 1
    end
  end

  def usage
    <<~TEXT
      使い方:
        bin/evaluate runs/specs/01.yml
        bin/evaluate --problem 01 [--model MODEL] [--time-limit 30m] [--silence-limit 5m] [--show-target] [--prompt TEXT]
        bin/evaluate --all [--jobs N] [--time-limit 30m] [--show-target]

      認証（どちらか必須）:
        export CLAUDE_CODE_OAUTH_TOKEN=...   # claude setup-token。Google ログインのアカウントで発行できる
        bin/evaluate --credentials-from ~/.claude   # Linux の .credentials.json だけをコピーする

      出力:
        $GOLF_RUNS_DIR/runs/<時刻>-<問題>/   既定の GOLF_RUNS_DIR は ~/golf-runs
        作業ディレクトリとログは消さない。リポジトリの中には置けない。
    TEXT
  end

  def parse_args(argv)
    opts = { jobs: 1 }
    positional = []
    rest = argv.dup
    while (arg = rest.shift)
      case arg
      when "--all" then opts[:all] = true
      when "--show-target" then opts[:show_target] = true
      when "--problem" then opts[:problem] = need_value(rest, arg)
      when "--model" then opts[:model] = need_value(rest, arg)
      when "--time-limit" then opts[:time_limit] = need_value(rest, arg)
      when "--silence-limit" then opts[:silence_limit] = need_value(rest, arg)
      when "--prompt" then opts[:prompt] = need_value(rest, arg)
      when "--jobs" then opts[:jobs] = Integer(need_value(rest, arg))
      when "--runs-dir" then opts[:runs_dir] = need_value(rest, arg)
      when "--credentials-from" then opts[:credentials_from] = need_value(rest, arg)
      when "--help", "-h" then opts[:help] = true
      else
        abort "不明な引数: #{arg}" if arg.start_with?("-")
        positional << arg
      end
    end
    abort "仕様ファイルは1つだけ指定できます" if positional.size > 1
    abort "--all と仕様ファイルは同時に指定できません" if opts[:all] && positional.any?
    abort "--jobs は 1 以上です" if opts[:jobs] < 1
    opts[:spec_path] = positional.first
    opts
  end

  def need_value(rest, flag)
    value = rest.shift
    abort "#{flag} に値が必要です" if value.nil? || value.start_with?("-")
    value
  end

  def parse_duration(value)
    text = value.to_s.strip
    seconds = case text
    when /\A\d+(?:\.\d+)?\z/ then Float(text)
    when /\A(\d+(?:\.\d+)?)s(?:ec)?\z/ then Float($1)
    when /\A(\d+(?:\.\d+)?)m(?:in)?\z/ then Float($1) * 60
    when /\A(\d+(?:\.\d+)?)h(?:our)?\z/ then Float($1) * 3600
    else
      abort "時間の指定が不正です: #{value}"
    end
    abort "時間は 0 より大きくしてください: #{value}" unless seconds.positive?
    seconds
  end

  def prepare!(opts)
    opts[:runs_root] = File.expand_path(opts[:runs_dir] || ENV["GOLF_RUNS_DIR"] || File.join(Dir.home, "golf-runs"))
    abort "実行ディレクトリがリポジトリの中です: #{opts[:runs_root]}\n権限の deny とサンドボックスがリポジトリを隠すので、GOLF_RUNS_DIR はリポジトリの外にしてください" if inside_repo?(opts[:runs_root])
    opts[:credentials_from] = File.expand_path(opts[:credentials_from]) if opts[:credentials_from]
    opts[:credentials_from] ||= File.expand_path(ENV["GOLF_CLAUDE_CREDENTIALS_FROM"]) if ENV["GOLF_CLAUDE_CREDENTIALS_FROM"].to_s != ""
    check_auth!(opts[:credentials_from])
    opts[:claude] = claude_executable
  end

  def check_auth!(credentials_from)
    return if oauth_token
    if credentials_from
      file = File.join(credentials_from, CREDENTIALS_NAME)
      return if File.file?(file)

      abort "資格情報ファイルがありません: #{file}\nmacOS では Keychain に入るため、claude setup-token で作った CLAUDE_CODE_OAUTH_TOKEN を使ってください"
    end

    warn <<~MSG
      認証がありません。実行しません。
      Claude のサブスクリプション（Google ログイン）では、次が標準です。
        1. claude setup-token を実行する
        2. ブラウザで Google ログインを選ぶ
        3. 表示されたトークンを環境変数にする（ファイルや git には入れない）
           export CLAUDE_CODE_OAUTH_TOKEN='...'
      Linux でログイン済みの設定ディレクトリがある場合は、.credentials.json だけをコピーできます。
        bin/evaluate --credentials-from ~/.claude
      macOS は資格情報が Keychain に入るため、setup-token の方を使ってください。
    MSG
    abort "認証が無いため中止しました"
  end

  def oauth_token
    token = ENV["CLAUDE_CODE_OAUTH_TOKEN"].to_s
    token.strip.empty? ? nil : token
  end

  def claude_executable
    name = ENV["GOLF_CLAUDE"].to_s
    name = "claude" if name.empty?
    if name.include?("/")
      return name if File.executable?(name)
      abort "claude が見つかりません: #{name}"
    end
    ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).each do |dir|
      path = File.join(dir, name)
      return path if File.executable?(path)
    end
    abort "claude が見つかりません。PATH に claude を置くか、GOLF_CLAUDE で実行ファイルを指定してください"
  end

  def inside_repo?(path)
    root = File.realpath(ROOT)
    current = File.expand_path(path)
    until File.exist?(current)
      parent = File.dirname(current)
      break if parent == current
      current = parent
    end
    real = File.realpath(current)
    real == root || real.start_with?(root + "/")
  end

  def problem_dirs
    Dir[File.join(ROOT, "problems", "*", "problem.yml")].sort
  end

  def problem_ids
    problem_dirs.map { YAML.safe_load_file(_1).fetch("id") }
  end

  def resolve_problem(problem)
    matches = Dir[File.join(ROOT, "problems", "#{problem}*")].select { File.directory?(_1) }.sort
    abort "問題が見つかりません: #{problem}" if matches.empty?
    abort "問題の指定が曖昧です: #{problem}（#{matches.map { File.basename(_1) }.join(", ")}）" if matches.size > 1
    matches.first
  end

  def effective_spec(opts, problem: nil)
    base = {}
    if opts[:spec_path]
      abort "仕様ファイルがありません: #{opts[:spec_path]}" unless File.file?(opts[:spec_path])
      base = YAML.safe_load_file(opts[:spec_path]) || {}
      abort "仕様ファイルはマッピングである必要があります" unless base.is_a?(Hash)
    end
    show_target = opts.key?(:show_target) ? opts[:show_target] : !!base["show_target"]
    {
      "problem" => (problem || opts[:problem] || base["problem"]).to_s,
      "model" => (opts[:model] || base["model"])&.to_s,
      "time_limit" => opts[:time_limit] || base["time_limit"] || DEFAULT_TIME_LIMIT,
      "silence_limit" => opts[:silence_limit] || base["silence_limit"] || DEFAULT_SILENCE_LIMIT,
      "show_target" => show_target,
      "prompt" => opts[:prompt] || base["prompt"] || DEFAULT_PROMPT,
    }
  end

  def run_all(opts)
    ids = problem_ids
    queue = Queue.new
    ids.each { |id| queue << id }
    outcomes = Queue.new
    threads = opts[:jobs].times.map do
      Thread.new do
        loop do
          begin
            id = queue.pop(true)
          rescue ThreadError
            break
          end
          spec = effective_spec(opts, problem: id)
          outcomes << run_one(spec, opts)
        end
      end
    end
    threads.each(&:join)
    failed = 0
    outcomes.size.times do
      failed += 1 unless outcomes.pop[:ok]
    end
    failed.zero? ? 0 : 1
  end

  def run_one(spec, opts)
    started = monotonic
    layout = provision(spec, opts)
    reason = run_claude(spec, opts, layout)
    result = collect(spec, layout, reason, monotonic - started)
    puts "#{result["problem"]}: #{reason} accepted=#{result["accepted"]} bytes=#{result["bytes"].inspect} delta=#{result["delta"].inspect} -> #{layout[:run_dir]}"
    { ok: true, result: result }
  rescue StandardError => e
    warn "#{spec["problem"]}: #{e.message}"
    { ok: false, error: e.message }
  end

  def provision(spec, opts)
    dir = resolve_problem(spec["problem"])
    meta = YAML.safe_load_file(File.join(dir, "problem.yml"))
    slug = meta["slug"].to_s
    slug = meta["id"].to_s if slug.empty?
    safe = slug.gsub(/[^A-Za-z0-9._-]/, "-")
    stamp = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
    run_dir = File.join(opts[:runs_root], "runs", "#{stamp}-#{safe}")
    run_dir = "#{run_dir}-#{format("%03d", rand(1000))}" while File.exist?(run_dir)
    workspace = File.join(run_dir, "workspace")
    settings = File.join(run_dir, "settings")
    claude_config = File.join(run_dir, "claude-config")
    FileUtils.mkdir_p(run_dir)
    args = [RbConfig.ruby, EXPORT, spec["problem"], workspace, "--run-dir=#{settings}"]
    args << "--show-target" if spec["show_target"]
    _out, err, status = Open3.capture3(*args)
    raise "作業ディレクトリの作成に失敗しました: #{err.strip}" unless status.success?

    FileUtils.mkdir_p(claude_config)
    copy_credentials(opts[:credentials_from], claude_config)
    {
      run_dir: run_dir,
      workspace: workspace,
      settings: settings,
      claude_config: claude_config,
      meta: meta,
      problem_dir: dir,
    }
  end

  # ログイン済み設定からは資格情報ファイルだけをコピーする。設定や MCP や CLAUDE.md はコピーしない。
  def copy_credentials(source, claude_config)
    return unless source

    file = File.join(source, CREDENTIALS_NAME)
    return unless File.file?(file)

    dest = File.join(claude_config, CREDENTIALS_NAME)
    FileUtils.cp(file, dest)
    File.chmod(0o600, dest)
  end

  def run_claude(spec, opts, layout)
    time_limit = parse_duration(spec["time_limit"])
    silence_limit = parse_duration(spec["silence_limit"])
    cmd = [
      opts[:claude], "-p", spec["prompt"],
      "--settings", File.join(layout[:settings], "settings.json"),
      "--mcp-config", File.join(layout[:settings], "golf-mcp.json"),
      "--strict-mcp-config",
      "--permission-mode", "dontAsk",
      "--output-format", "stream-json",
      "--verbose",
    ]
    cmd += ["--model", spec["model"]] if spec["model"] && !spec["model"].empty?
    env = ENV.to_h.merge("CLAUDE_CONFIG_DIR" => layout[:claude_config])
    stream_path = File.join(layout[:run_dir], "stream.jsonl")
    stderr_path = File.join(layout[:run_dir], "claude.stderr.log")
    out_r, out_w = IO.pipe
    err_r, err_w = IO.pipe
    stream = File.open(stream_path, "wb")
    stderr = File.open(stderr_path, "wb")
    pid = nil
    reaped = false
    last_output = monotonic
    lock = Mutex.new
    mark = lambda do
      lock.synchronize { last_output = monotonic }
    end
    pumps = []
    reason = "error"
    begin
      pid = Process.spawn(env, *cmd, chdir: layout[:workspace], pgroup: true, in: File::NULL, out: out_w, err: err_w)
      out_w.close
      err_w.close
      pumps << Thread.new { pump(out_r, stream, mark) }
      pumps << Thread.new { pump(err_r, stderr, mark) }
      deadline = monotonic + time_limit
      loop do
        got = Process.wait2(pid, Process::WNOHANG)
        if got
          reaped = true
          reason = got[1].success? ? "finished" : "error"
          break
        end
        now = monotonic
        if now >= deadline
          reason = "timeout"
          kill_group(pid)
          Process.wait2(pid)
          reaped = true
          break
        end
        quiet_for = now - lock.synchronize { last_output }
        if quiet_for >= silence_limit
          reason = "silence"
          kill_group(pid)
          Process.wait2(pid)
          reaped = true
          break
        end
        sleep 0.1
      end
    rescue Errno::ENOENT
      reason = "error"
    ensure
      out_w.close rescue nil
      err_w.close rescue nil
      if pid && !reaped
        kill_group(pid)
        Process.wait2(pid) rescue nil
      end
      pumps.each { _1.join(2) }
      stream.close rescue nil
      stderr.close rescue nil
      out_r.close rescue nil
      err_r.close rescue nil
    end
    reason
  end

  def pump(io, dest, on_activity)
    while (chunk = io.readpartial(8192))
      dest.write(chunk)
      dest.flush
      on_activity.call
    end
  rescue EOFError
    nil
  end

  def kill_group(pid)
    Process.kill("KILL", -pid)
  rescue Errno::ESRCH, Errno::EPERM
    Process.kill("KILL", pid)
  rescue Errno::ESRCH, Errno::EPERM
    nil
  end

  def collect(spec, layout, reason, wall)
    answer = File.join(layout[:workspace], "answer.rb")
    judge = grade(spec["problem"], answer)
    accepted = judge.is_a?(Hash) && judge["accepted"] == true
    bytes = judge.is_a?(Hash) ? judge["bytes"] : nil
    target = layout[:meta]["target_bytes"]
    usage, judge_calls, run_ruby_calls = summarize_stream(File.join(layout[:run_dir], "stream.jsonl"))
    result = {
      "problem" => layout[:meta]["slug"] || layout[:meta]["id"],
      "accepted" => accepted,
      "bytes" => bytes,
      "target_bytes" => target,
      "delta" => bytes.nil? || target.nil? ? nil : bytes - target,
      "wall_time_sec" => wall.round(3),
      "token_usage" => usage,
      "judge_calls" => judge_calls,
      "run_ruby_calls" => run_ruby_calls,
      "exit_reason" => reason,
      "time_limit_sec" => parse_duration(spec["time_limit"]),
      "silence_limit_sec" => parse_duration(spec["silence_limit"]),
      "model" => spec["model"],
      "show_target" => spec["show_target"],
      "run_dir" => layout[:run_dir],
      "judge" => judge,
    }
    File.write(File.join(layout[:run_dir], "result.json"), JSON.pretty_generate(result) + "\n")
    result
  end

  def grade(problem, answer)
    return nil unless File.file?(answer)

    out, _err, _status = Open3.capture3(RbConfig.ruby, JUDGE, problem, answer, "--json")
    JSON.parse(out)
  rescue JSON::ParserError
    nil
  end

  def summarize_stream(path)
    usage = nil
    judge_calls = 0
    run_ruby_calls = 0
    return [nil, 0, 0] unless File.file?(path)

    File.open(path, "rb") do |io|
      io.each_line do |line|
        text = line.force_encoding(Encoding::UTF_8).scrub.strip
        next if text.empty?
        begin
          event = JSON.parse(text)
        rescue JSON::ParserError
          next
        end
        found = event["usage"] if event.is_a?(Hash) && event["usage"].is_a?(Hash)
        found ||= event.dig("message", "usage") if event.is_a?(Hash) && event.dig("message", "usage").is_a?(Hash)
        usage = found if found
        each_tool_name(event) do |name|
          case tool_kind(name)
          when :judge then judge_calls += 1
          when :run_ruby then run_ruby_calls += 1
          end
        end
      end
    end
    [usage, judge_calls, run_ruby_calls]
  end

  def each_tool_name(obj, &block)
    case obj
    when Hash
      yield obj["name"] if obj["type"] == "tool_use" && obj["name"]
      obj.each_value { each_tool_name(_1, &block) }
    when Array
      obj.each { each_tool_name(_1, &block) }
    end
  end

  def tool_kind(name)
    return :judge if name == "mcp__golf__judge" || (name.end_with?("__judge") && name.include?("golf"))
    return :run_ruby if name == "mcp__golf__run_ruby" || (name.end_with?("__run_ruby") && name.include?("golf"))
    nil
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
