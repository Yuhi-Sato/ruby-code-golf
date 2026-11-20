# frozen_string_literal: true

# 評価ランナーを、本物の Claude の代わりに test/support/fake_claude.rb で確認する。
# 準備、実行、時間切れ、無通信、回収、プロセスグループの停止、認証の不足を見る。
#   ruby test/evaluate_runner_test.rb

require "json"
require "open3"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
RUBY = RbConfig.ruby
EVALUATE = File.join(ROOT, "bin", "evaluate")
FAKE = File.join(ROOT, "test", "support", "fake_claude.rb")
SOLUTION = File.join(ROOT, "private", "01-tally-marks", "solution.rb")
TOKEN = "test-oauth-token-not-real"

fail = false
check = lambda do |cond, msg|
  next if cond

  warn "FAIL: #{msg}"
  fail = true
end

def child_env(stub_dir, extra = {})
  env = ENV.to_h
  env.delete("CLAUDE_CODE_OAUTH_TOKEN")
  env.delete("GOLF_CLAUDE_CREDENTIALS_FROM")
  env.delete("GOLF_CLAUDE")
  env["PATH"] = "#{stub_dir}#{File::PATH_SEPARATOR}#{ENV["PATH"]}"
  env["GOLF_SANDBOX"] = "off"
  env.merge(extra)
end

def run_eval(env, *args)
  Open3.capture3(env, RUBY, EVALUATE, *args)
end

def results_under(root)
  Dir[File.join(root, "runs", "*", "result.json")].map { JSON.parse(File.read(_1)) }
end

Dir.mktmpdir("golf-eval") do |tmp|
  stub_dir = File.join(tmp, "bin")
  Dir.mkdir(stub_dir)
  stub = File.join(stub_dir, "claude")
  File.symlink(FAKE, stub)
  File.chmod(0o755, FAKE)

  # 認証が無いと、実行ディレクトリを作る前に止まる。
  bare = File.join(tmp, "no-auth")
  _out, err, status = run_eval(child_env(stub_dir), "--problem", "01", "--runs-dir", bare, "--time-limit", "5s")
  check.call(!status.success?, "missing auth exited 0")
  check.call(err.include?("CLAUDE_CODE_OAUTH_TOKEN") && err.include?("setup-token"), "auth message:\n#{err}")
  check.call(!File.exist?(bare), "runner created #{bare} without auth")

  empty = File.join(tmp, "empty-config")
  Dir.mkdir(empty)
  _out, err, status = run_eval(
    child_env(stub_dir),
    "--credentials-from", empty, "--problem", "01", "--runs-dir", File.join(tmp, "no-cred-file"), "--time-limit", "5s",
  )
  check.call(!status.success? && err.include?(".credentials.json") && err.include?("Keychain"), "missing credentials file:\n#{err}")

  runs_before = Dir.children(File.join(ROOT, "runs"))
  _out, err, status = run_eval(
    child_env(stub_dir, "CLAUDE_CODE_OAUTH_TOKEN" => TOKEN),
    "--problem", "01", "--runs-dir", ROOT, "--time-limit", "5s",
  )
  check.call(!status.success? && err.include?("リポジトリ"), "inside-repo runs dir was allowed:\n#{err}")
  check.call(Dir.children(File.join(ROOT, "runs")) == runs_before, "runner wrote into the repo runs/ directory")

  # 仕様ファイルから、スタブが正解を書いて終わる。
  runs = File.join(tmp, "ok")
  out, err, status = run_eval(
    child_env(stub_dir, "CLAUDE_CODE_OAUTH_TOKEN" => TOKEN, "FAKE_CLAUDE_ANSWER_FILE" => SOLUTION),
    File.join(ROOT, "runs", "specs", "01.yml"),
    "--runs-dir", runs, "--time-limit", "20s", "--silence-limit", "15s", "--show-target", "--model", "fake-model",
  )
  check.call(status.success?, "happy path failed: #{status.exitstatus}\n#{out}\n#{err}")
  found = results_under(runs)
  check.call(found.size == 1, "expected 1 result, got #{found.size}")
  if (result = found.first)
    run_dir = result["run_dir"]
    workspace = File.join(run_dir, "workspace")
    check.call(result["exit_reason"] == "finished", result["exit_reason"])
    check.call(result["accepted"] == true && result["bytes"] == 56 && result["target_bytes"] == 56 && result["delta"] == 0, result.slice("accepted", "bytes", "target_bytes", "delta"))
    check.call(result.dig("token_usage", "input_tokens") == 100 && result.dig("token_usage", "output_tokens") == 40, result["token_usage"])
    check.call(result["judge_calls"] == 2 && result["run_ruby_calls"] == 1, result.slice("judge_calls", "run_ruby_calls"))
    check.call(result.dig("judge", "cases").any? { _1["kind"] == "hidden" && _1["status"] == "accepted" }, "operator judge detail missing")
    check.call(File.file?(File.join(workspace, "answer.rb")), "answer.rb was deleted")
    check.call(File.file?(File.join(workspace, "PROBLEM.md")), "workspace missing")
    check.call(File.read(File.join(workspace, "PROBLEM.md"), encoding: "UTF-8").include?("目標"), "show_target did not reach PROBLEM.md")
    check.call(File.file?(File.join(run_dir, "settings", "settings.json")), "settings missing")
    check.call(File.file?(File.join(run_dir, "stream.jsonl")), "stream log missing")
    check.call(!run_dir.start_with?(ROOT + "/"), "run dir is inside the repo: #{run_dir}")
    check.call(Dir.children(File.join(run_dir, "claude-config")).empty?, "token run copied extra config")
    text = File.read(File.join(run_dir, "result.json")) + File.read(File.join(run_dir, "stream.jsonl"))
    check.call(!text.include?(TOKEN), "token leaked into logs")
    argv = JSON.parse(File.read(File.join(workspace, "claude.argv.json")))
    %w[--strict-mcp-config --verbose --output-format stream-json --permission-mode dontAsk --settings --mcp-config -p --model fake-model].each do |flag|
      check.call(argv.include?(flag), "claude argv missing #{flag}: #{argv}")
    end
    prompt = argv[argv.index("-p") + 1]
    check.call(prompt.include?("CONDITIONS.md") && prompt.include?("answer.rb"), prompt)
  end

  # 制限時間でプロセスグループごと止める。作業ディレクトリは残す。
  runs = File.join(tmp, "timeout")
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  out, err, status = run_eval(
    child_env(stub_dir, "CLAUDE_CODE_OAUTH_TOKEN" => TOKEN, "FAKE_CLAUDE_MODE" => "timeout", "FAKE_CLAUDE_ANSWER_FILE" => SOLUTION),
    "--problem", "01", "--runs-dir", runs, "--time-limit", "1s", "--silence-limit", "30s",
  )
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  check.call(status.success?, "timeout run failed: #{err}\n#{out}")
  result = results_under(runs).first
  check.call(result && result["exit_reason"] == "timeout", "timeout reason #{result&.dig("exit_reason")}")
  check.call(elapsed < 10, "timeout run took #{elapsed.round(2)}s")
  check.call(result && result["accepted"] == true, "collect after timeout did not grade the answer: #{result&.slice("accepted", "bytes")}")
  sleep 0.3
  check.call(!`ps -eo args`.include?("fake_claude.rb"), "process group still alive after timeout")

  # 出力が止まったら silence で止める。
  runs = File.join(tmp, "silence")
  started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  out, err, status = run_eval(
    child_env(stub_dir, "CLAUDE_CODE_OAUTH_TOKEN" => TOKEN, "FAKE_CLAUDE_MODE" => "silence"),
    "--problem", "01", "--runs-dir", runs, "--time-limit", "30s", "--silence-limit", "1s",
  )
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  check.call(status.success?, "silence run failed: #{err}\n#{out}")
  result = results_under(runs).first
  check.call(result && result["exit_reason"] == "silence", "silence reason #{result&.dig("exit_reason")}")
  check.call(elapsed < 10, "silence run took #{elapsed.round(2)}s")
  check.call(File.directory?(File.join(result["run_dir"], "workspace")), "silence run deleted the workspace") if result
  sleep 0.3
  check.call(!`ps -eo args`.include?("fake_claude.rb"), "process group still alive after silence")

  # 非ゼロ終了は error。answer.rb が無くても result.json は残る。
  runs = File.join(tmp, "error")
  _out, err, status = run_eval(
    child_env(stub_dir, "CLAUDE_CODE_OAUTH_TOKEN" => TOKEN, "FAKE_CLAUDE_MODE" => "error"),
    "--problem", "01", "--runs-dir", runs, "--time-limit", "10s",
  )
  check.call(status.success?, "error run failed: #{err}")
  result = results_under(runs).first
  check.call(result && result["exit_reason"] == "error" && result["accepted"] == false && result["bytes"].nil?, result)
  check.call(result && !File.exist?(File.join(result["run_dir"], "workspace", "answer.rb")), "error mode wrote answer.rb")
  check.call(result && File.file?(File.join(result["run_dir"], "workspace", "PROBLEM.md")), "workspace removed after error")

  # 資格情報ファイルだけをコピーする。
  source = File.join(tmp, "logged-in")
  Dir.mkdir(source)
  File.write(File.join(source, ".credentials.json"), "{\"claudeAiOauth\":{\"accessToken\":\"copied-secret\"}}\n")
  File.write(File.join(source, "settings.json"), "{\"leak\":true}\n")
  File.write(File.join(source, "CLAUDE.md"), "do not copy\n")
  File.write(File.join(source, "mcp.json"), "{}\n")
  runs = File.join(tmp, "creds")
  _out, err, status = run_eval(
    child_env(stub_dir),
    "--credentials-from", source, "--problem", "02", "--runs-dir", runs, "--time-limit", "10s",
  )
  check.call(status.success?, "credentials run failed: #{err}")
  result = results_under(runs).first
  config = File.join(result["run_dir"], "claude-config")
  names = Dir.children(config).sort
  check.call(names == [".credentials.json"], "copied extra files: #{names}")
  check.call(File.read(File.join(config, ".credentials.json")).include?("copied-secret"), "credentials content missing")
  check.call(File.stat(File.join(config, ".credentials.json")).mode & 0o777 == 0o600, "credentials mode is not 0600")
  check.call(!File.read(File.join(result["run_dir"], "result.json")).include?("copied-secret"), "credentials leaked into result.json")

  # 全問を2並列。スタブは解答を書かないので採点は走らない。
  runs = File.join(tmp, "all")
  out, err, status = run_eval(
    child_env(stub_dir, "CLAUDE_CODE_OAUTH_TOKEN" => TOKEN),
    "--all", "--jobs", "2", "--runs-dir", runs, "--time-limit", "15s", "--silence-limit", "10s",
  )
  check.call(status.success?, "all problems failed: #{status.exitstatus}\n#{out}\n#{err}")
  all = results_under(runs)
  check.call(all.size == 18, "expected 18 results, got #{all.size}: #{all.map { _1["problem"] }}")
  check.call(all.all? { _1["exit_reason"] == "finished" && _1["accepted"] == false }, "unexpected all-run result")
end

exit(fail ? 1 : 0)
