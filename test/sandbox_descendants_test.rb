# frozen_string_literal: true

# setsid した孫が制限時間を超えて生き残らないことと、
# macOS 用プロファイルが書き込みと exec を絞っていることを確認する。
# プロファイルの実行は macOS が無いので文字列の検査だけ。
#   ruby test/sandbox_descendants_test.rb

require "rbconfig"
require "tmpdir"
require_relative "../lib/golf_sandbox"

fail = false
check = lambda do |cond, msg|
  next if cond

  warn "FAIL: #{msg}"
  fail = true
end

def elapsed
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  result = yield
  [result, Process.clock_gettime(Process::CLOCK_MONOTONIC) - start]
end

def cmdline_has?(marker)
  `ps -eo args`.include?(marker)
end

marker = "golfsetsid#{Process.pid}#{rand(1000)}"
begin
  # 本体はすぐ終わるが、setsid した孫が stdout を握って 30 秒寝る。
  quick = %{fork { Process.setsid; sleep 30 }; sleep 0.2; print #{marker.dump}}
  ENV["GOLF_SANDBOX"] = "off"
  (status, out, err), dt = elapsed { GolfSandbox.run(["-e", quick], "", time_limit: 8) }
  check.call(status == :ok && out == marker, "off quick status=#{status} out=#{out.inspect} err=#{err} dt=#{dt.round(2)}")
  check.call(dt < 3, "off quick took #{dt.round(2)}s")
  check.call(!cmdline_has?(marker), "setsid grandchild still running after off quick")

  # 本体も制限を超えて寝る。孫も一緒に止まること。
  slow = %{fork { Process.setsid; sleep 30 }; sleep 30; print #{marker.dump}}
  (status, _out, err), dt = elapsed { GolfSandbox.run(["-e", slow], "", time_limit: 1) }
  check.call(status == :timeout, "off slow status=#{status} err=#{err} dt=#{dt.round(2)}")
  check.call(dt < 3, "off slow took #{dt.round(2)}s")
  check.call(!cmdline_has?(marker), "setsid grandchild still running after off timeout")

  ENV["GOLF_SANDBOX"] = "bwrap"
  (status, out, err), dt = elapsed { GolfSandbox.run(["-e", quick], "", time_limit: 8) }
  check.call(status == :ok && out == marker, "bwrap quick status=#{status} out=#{out.inspect} err=#{err}")
  check.call(dt < 3, "bwrap quick took #{dt.round(2)}s")
  check.call(!cmdline_has?(marker), "setsid grandchild still running after bwrap")
ensure
  system("pkill", "-f", marker, out: File::NULL, err: File::NULL)
end

Dir.mktmpdir("golf-seatbelt") do |dir|
  profile = GolfSandbox.seatbelt_profile(dir)
  real_tmp = File.realpath(dir)
  ruby = File.realpath(RbConfig.ruby)
  hidden = File.realpath(File.expand_path("..", __dir__))
  [
    "(allow default)",
    "(deny network*)",
    "(deny file-write*)",
    "(allow file-write*",
    real_tmp,
    "(deny process-exec*)",
    "(allow process-exec",
    ruby,
    hidden,
  ].each do |piece|
    check.call(profile.include?(piece), "profile missing #{piece}:\n#{profile}")
  end
end

exit(fail ? 1 : 0)
