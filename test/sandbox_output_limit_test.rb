# frozen_string_literal: true

# 出力を際限なく溜めず、数MBで止めて :output_limit を返すことを確認する。
#   ruby test/sandbox_output_limit_test.rb

ENV["GOLF_SANDBOX"] = "off"

require "open3"
require "rbconfig"
require "tmpdir"
require_relative "../lib/golf_sandbox"

ROOT = File.expand_path("..", __dir__)
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

%w[stdout stderr].each do |stream|
  code = %(loop { $#{stream}.write("a" * 100_000) })
  status = nil
  out = err = nil
  dt = elapsed do
    status, out, err = GolfSandbox.run(["-e", code], "", time_limit: 5)
  end
  body = stream == "stdout" ? out : err
  check.call(status == :output_limit, "#{stream} status #{status} after #{dt.round(2)}s")
  check.call(body.bytesize <= GolfSandbox::OUTPUT_LIMIT, "#{stream} buffered #{body.bytesize} bytes")
  check.call(dt < 2, "#{stream} took #{dt.round(2)}s")
end

status, out, = GolfSandbox.run(["-e", "puts 'ok'"], "", time_limit: 2)
check.call(status == :ok && out.strip == "ok", "short output was #{status} #{out.inspect}")

Dir.mktmpdir("golf-out") do |dir|
  solution = File.join(dir, "big.rb")
  File.write(solution, "loop { $stdout.write('a' * 100_000) }\n")
  dt = elapsed do
    out, err, = Open3.capture3(
      { "GOLF_SANDBOX" => "off" },
      RbConfig.ruby, File.join(ROOT, "bin", "judge"), "01", solution,
    )
    check.call(out.include?("output_limit"), "judge did not report output_limit:\n#{out}\n#{err}")
    check.call(!err.include?("Error"), "judge crashed:\n#{err}")
  end
  check.call(dt < 5, "judge took #{dt.round(2)}s on an output flood")
end

exit(fail ? 1 : 0)
