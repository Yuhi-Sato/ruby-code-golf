# frozen_string_literal: true

# 解答の標準エラーが不正な UTF-8 でも bin/judge が落ちず、
# トレースバックでリポジトリのパスを漏らさないことを確認する。
#   ruby test/judge_stderr_encoding_test.rb

require "open3"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
fail = false
check = lambda do |cond, msg|
  next if cond

  warn "FAIL: #{msg}"
  fail = true
end

Dir.mktmpdir("golf-judge") do |dir|
  solution = File.join(dir, "bad.rb")
  File.write(solution, %($stderr.print "\\xff"; exit 1\n))
  out, err, status = Open3.capture3(
    { "GOLF_SANDBOX" => "off" },
    RbConfig.ruby, File.join(ROOT, "bin", "judge"), "01", solution,
  )

  check.call(!status.success?, "expected a failing solution, got exit #{status.exitstatus}")
  check.call(!err.include?("ArgumentError"), "judge crashed:\n#{err}")
  check.call(!err.include?(ROOT), "traceback leaked repo path:\n#{err}")
  check.call(out.include?("FAIL sample1"), "missing sample failure:\n#{out}")
  check.call(out.include?("hidden/01") && out.include?("hidden/03"), "hidden results were dropped:\n#{out}")
  check.call(out.include?("01-tally-marks:"), "summary missing:\n#{out}")
end

exit(fail ? 1 : 0)
