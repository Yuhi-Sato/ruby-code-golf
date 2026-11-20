# frozen_string_literal: true

# 制限時間の参照、古いテストファイルの削除、リポジトリ内への出力拒否、
# ラッパーが MCP と同じ Ruby を使うことを確認する。
#   ruby test/minor_cleanup_test.rb

require "json"
require "open3"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
RUBY = RbConfig.ruby
fail = false
check = lambda do |cond, msg|
  next if cond

  warn "FAIL: #{msg}"
  fail = true
end

yml = File.join(ROOT, "problems/01-tally-marks/problem.yml")
original = File.read(yml)
begin
  File.write(yml, original.sub("time_limit_per_case_sec: 5", "time_limit_per_case_sec: 0.4"))
  Dir.mktmpdir("golf-slow") do |dir|
    solution = File.join(dir, "slow.rb")
    File.write(solution, "sleep 1\n")
    out, err, = Open3.capture3(
      { "GOLF_SANDBOX" => "off", "GOLF_TIME_LIMIT" => "" },
      RUBY, File.join(ROOT, "bin", "judge"), "01", solution,
    )
    check.call(out.include?("timeout") && !err.include?("Error"), "yml limit was ignored:\n#{out}\n#{err}")
    out, err, = Open3.capture3(
      { "GOLF_SANDBOX" => "off", "GOLF_TIME_LIMIT" => "5" },
      RUBY, File.join(ROOT, "bin", "judge"), "01", solution,
    )
    check.call(!out.include?("timeout") && out.include?("wrong_answer"), "env override did not win:\n#{out}\n#{err}")
  end
ensure
  File.write(yml, original)
end

stale_dir = File.join(ROOT, "private/01-tally-marks/tests")
stale_in = File.join(stale_dir, "99.in")
stale_out = File.join(stale_dir, "99.out")
File.write(stale_in, "1\n")
File.write(stale_out, "x\n")
begin
  gen_out, gen_err, gen_status = Open3.capture3(RUBY, File.join(ROOT, "tools", "gen_tests.rb"), ROOT)
  check.call(gen_status.success?, "gen_tests failed: #{gen_err}\n#{gen_out}")
  check.call(!File.exist?(stale_in) && !File.exist?(stale_out), "stale 99.in/out were kept")
  check.call(File.exist?(File.join(stale_dir, "01.in")), "generator removed a live case")
  diff, = Open3.capture2("git", "-C", ROOT, "diff", "--stat", "--", "private")
  check.call(diff.empty?, "gen_tests rewrote existing tests:\n#{diff}")
ensure
  File.delete(stale_in) if File.exist?(stale_in)
  File.delete(stale_out) if File.exist?(stale_out)
end

inside = File.join(ROOT, "should-not-export")
_out, err, status = Open3.capture3(RUBY, File.join(ROOT, "tools", "export_workspace.rb"), "01", inside)
check.call(!status.success? && err.include?("リポジトリの中"), "inside-repo export was allowed: #{err}")
check.call(!File.exist?(inside), "export created #{inside}")

nested = File.join(ROOT, "no-such-parent", "out")
_out, err, status = Open3.capture3(RUBY, File.join(ROOT, "tools", "export_workspace.rb"), "01", nested)
check.call(!status.success?, "nested inside-repo export was allowed: #{err}")
check.call(!File.exist?(File.join(ROOT, "no-such-parent")), "export created a parent inside the repo")

Dir.mktmpdir("golf-ruby") do |dir|
  dest = File.join(dir, "ws")
  _out, err, status = Open3.capture3(RUBY, File.join(ROOT, "tools", "export_workspace.rb"), "01", dest)
  check.call(status.success?, "export outside the repo failed: #{err}")
  wrapper = File.read(File.join(dest, "judge"))
  check.call(wrapper.include?(RUBY), "wrapper does not use #{RUBY}:\n#{wrapper}")
  check.call(!wrapper.match?(/^exec ruby /), "wrapper still uses PATH ruby:\n#{wrapper}")
end

exit(fail ? 1 : 0)
