# frozen_string_literal: true

# bubblewrap が / を丸ごと見せず、/tmp とホームを空にすることを確認する。
# Ruby 本体と標準ライブラリの require は動くこと。
#   ruby test/bwrap_filesystem_test.rb

ENV["GOLF_SANDBOX"] = "bwrap"

require "rbconfig"
require "tmpdir"
require_relative "../lib/golf_sandbox"

fail = false
check = lambda do |cond, msg|
  next if cond

  warn "FAIL: #{msg}"
  fail = true
end

argv = GolfSandbox.bwrap_argv("/tmp")
ro = argv.each_cons(3).any? { |flag, src, dest| flag == "--ro-bind" && src == "/" && dest == "/" }
check.call(!ro, "bwrap still bind-mounts /: #{argv.inspect}")
tmpfs = argv.each_with_index.filter_map { |arg, i| argv[i + 1] if arg == "--tmpfs" }
check.call(tmpfs.include?("/tmp") && tmpfs.include?("/home"), "missing tmpfs for /tmp or /home: #{tmpfs}")

home = File.realpath(Dir.home)
sentinel_home = File.join(home, "golf-sentinel-#{Process.pid}")
sentinel_tmp = "/tmp/golf-sentinel-#{Process.pid}"
begin
File.write(sentinel_home, "secret-home")
File.write(sentinel_tmp, "secret-tmp")

code = <<~RUBY
  require "json"
  require "yaml"
  require "date"
  require "stringio"
  require "digest"
  require "pathname"
  require "fileutils"
  require "openssl"
  require "zlib"
  require "socket"
  require "ripper"
  require "etc"
  puts "requires=ok"
  puts "gem=" + (defined?(Gem) ? Gem::VERSION : "missing")
  puts "home_sentinel=" + File.exist?(#{sentinel_home.dump}).to_s
  puts "tmp_sentinel=" + File.exist?(#{sentinel_tmp.dump}).to_s
  puts "readme=" + File.exist?("/workspace/README.md").to_s
  puts "workspace=" + File.exist?("/workspace").to_s
  puts "solution=" + File.exist?("/workspace/private/01-tally-marks/solution.rb").to_s
  puts "tmp_entries=" + Dir["/tmp/*"].join(",")
RUBY

status, out, err = GolfSandbox.run(["-e", code], "ignored", time_limit: 5)
check.call(status == :ok, "sandbox run #{status}: #{err}")
check.call(out.include?("requires=ok"), out)
check.call(out.include?("gem=") && !out.include?("gem=missing"), "Gem:: disappeared: #{out}")
check.call(out.include?("home_sentinel=false"), out)
check.call(out.include?("tmp_sentinel=false"), out)
check.call(out.include?("readme=false"), out)
check.call(out.include?("workspace=false"), out)
check.call(out.include?("solution=false"), out)
check.call(!out.include?("golf-sentinel-"), "sentinel name leaked via /tmp listing:\n#{out}")

Dir.mktmpdir("golf-bwrap-src") do |dir|
  script = File.join(dir, "answer.rb")
  File.write(script, <<~'RUBY')
    require "json"
    print STDIN.read.upcase
  RUBY
  status, out, err = GolfSandbox.run_file(script, "ok\n", time_limit: 5)
  check.call(status == :ok && out == "OK\n", "run_file #{status} out=#{out.inspect} err=#{err}")
end
ensure
  File.delete(sentinel_home) if sentinel_home && File.exist?(sentinel_home)
  File.delete(sentinel_tmp) if sentinel_tmp && File.exist?(sentinel_tmp)
end

exit(fail ? 1 : 0)
