# frozen_string_literal: true

# 制限時間が、大きな標準入力の書き込み中も効くことを確認する。
#   ruby test/sandbox_timer_test.rb

ENV["GOLF_SANDBOX"] = "off"

require "rbconfig"
require_relative "../lib/golf_sandbox"

fail = false
check = lambda do |cond, msg|
  next if cond

  warn "FAIL: #{msg}"
  fail = true
end

def elapsed
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield
  Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
end

dt = elapsed do
  status, = GolfSandbox.run(["-e", "sleep 5"], "a" * 200_000, time_limit: 0.8)
  check.call(status == :timeout, "large stdin slept instead of timing out (#{status})")
end
check.call(dt < 2, "large stdin run took #{dt.round(2)}s")

dt = elapsed do
  status, = GolfSandbox.run(["-e", "sleep 5"], "", time_limit: 0.6)
  check.call(status == :timeout, "empty stdin did not time out (#{status})")
end
check.call(dt < 2, "empty stdin sleep took #{dt.round(2)}s")

status, out, = GolfSandbox.run(["-e", "print STDIN.read.bytesize"], "a" * 200_000, time_limit: 3)
check.call(status == :ok && out == "200000", "reading large stdin failed: #{status} #{out.inspect}")

status, out, = GolfSandbox.run(["-e", "puts 1"], "", time_limit: 2)
check.call(status == :ok && out.strip == "1", "simple program failed: #{status} #{out.inspect}")

exit(fail ? 1 : 0)
