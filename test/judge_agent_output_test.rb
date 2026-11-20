# frozen_string_literal: true

# エージェント向けの採点は、非公開テストのケースごと・失敗の種類を出さない。
# 運営者向けの --json / --verbose はケースごとの結果を残す。
#   ruby test/judge_agent_output_test.rb

require "json"
require "open3"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
JUDGE = File.join(ROOT, "bin", "judge")
# サンプル（3行、どれも 20 以下）は正解。行数が多い非公開は runtime_error、
# 行数は少ないが 20 を超える非公開は wrong_answer になる。
SOLUTION = <<~'RUBY'
  lines = STDIN.readlines
  exit 1 if lines.size > 6
  lines.each do |l|
    n = l.to_i
    if n > 20
      puts "NO"
    else
      puts "正" * (n / 5) + " 一丅下止"[n % 5]
    end
  end
RUBY

fail = false
check = lambda do |cond, msg|
  next if cond

  warn "FAIL: #{msg}"
  fail = true
end

def run_judge(*args)
  Open3.capture3({ "GOLF_SANDBOX" => "off" }, RbConfig.ruby, JUDGE, "01", *args)
end

def redacted?(text)
  text.include?("PASS sample1") &&
    text.include?("hidden: 0/3 passed") &&
    !text.include?("hidden/") &&
    !text.include?("runtime_error") &&
    !text.include?("wrong_answer") &&
    !text.include?("49")
end

Dir.mktmpdir("golf-agent") do |dir|
  solution = File.join(dir, "probe.rb")
  File.write(solution, SOLUTION)

  out, err, = run_judge(solution, "--agent")
  check.call(err.empty? && redacted?(out), "agent output leaked hidden detail:\n#{out}\n#{err}")

  out, = run_judge(solution, "--agent", "--verbose", "--json")
  check.call(redacted?(out), "--agent did not override --json/--verbose:\n#{out}")

  out, = run_judge(solution, "--json")
  body = JSON.parse(out)
  statuses = body["cases"].to_h { |c| [c["name"], c["status"]] }
  check.call(statuses["sample1"] == "accepted", "sample should pass: #{statuses}")
  check.call(statuses.values.include?("runtime_error"), "json lost runtime_error: #{body}")
  check.call(statuses.values.include?("wrong_answer"), "json lost wrong_answer: #{body}")
  check.call(body["cases"].any? { _1["kind"] == "hidden" }, "json lost hidden cases")

  out, = run_judge(solution, "--verbose")
  check.call(out.include?("hidden/") && out.include?("runtime_error") && out.include?("wrong_answer"),
    "verbose lost per-case detail:\n#{out}")

  out, = run_judge(solution)
  check.call(out.include?("hidden/01") && out.include?("runtime_error"), "default lost hidden status:\n#{out}")

  req = {
    jsonrpc: "2.0", id: 1, method: "tools/call",
    params: { name: "judge", arguments: { file: "probe.rb" } },
  }
  ws = File.join(dir, "ws")
  Dir.mkdir(ws)
  File.write(File.join(ws, "probe.rb"), SOLUTION)
  mout, merr, mstat = Open3.capture3(
    { "GOLF_SANDBOX" => "off" },
    RbConfig.ruby, File.join(ROOT, "tools", "golf_mcp.rb"), "01", ws,
    stdin_data: JSON.generate(req) + "\n",
  )
  check.call(mstat.success?, "mcp exited #{mstat.exitstatus}: #{merr}")
  text = JSON.parse(mout).dig("result", "content", 0, "text").to_s
  check.call(redacted?(text), "mcp judge leaked hidden detail:\n#{text}")

  dest = File.join(dir, "exported")
  _eout, eerr, estat = Open3.capture3(RbConfig.ruby, File.join(ROOT, "tools", "export_workspace.rb"), "01", dest)
  check.call(estat.success?, "export failed: #{eerr}")
  File.write(File.join(dest, "probe.rb"), SOLUTION)
  wout, werr, = Open3.capture3(
    { "GOLF_SANDBOX" => "off" }, File.join(dest, "judge"), "probe.rb", "--verbose", chdir: dest,
  )
  check.call(werr.empty? && redacted?(wout), "workspace ./judge leaked hidden detail:\n#{wout}\n#{werr}")
end

exit(fail ? 1 : 0)
