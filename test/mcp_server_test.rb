# frozen_string_literal: true

# golf_mcp.rb が、1件の失敗でプロセスを終了しないことを確認する。
#   ruby test/mcp_server_test.rb

require "json"
require "open3"
require "rbconfig"
require "tmpdir"

fail = false
check = lambda do |cond, msg|
  next if cond

  warn "FAIL: #{msg}"
  fail = true
end

Dir.mktmpdir("golf-mcp") do |dir|
  reqs = [
    { jsonrpc: "2.0", id: 1, method: "tools/call", params: { name: "run_ruby", arguments: { code: '$><<"\xff\xfe"' } } },
    { jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "judge", arguments: 1 } },
    { jsonrpc: "2.0", id: 3, method: "ping" },
  ]
  input = reqs.map { JSON.generate(_1) }.join("\n") + "\n"
  out, err, status = Open3.capture3(
    { "GOLF_SANDBOX" => "off" },
    RbConfig.ruby, File.expand_path("../tools/golf_mcp.rb", __dir__), "01", dir,
    stdin_data: input,
  )

  check.call(status.success?, "server exit #{status.exitstatus}, stderr=#{err}")
  check.call(!err.include?("GeneratorError"), "stderr leaked GeneratorError:\n#{err}")
  lines = out.lines.map(&:strip).reject(&:empty?)
  check.call(lines.size == 3, "expected 3 responses, got #{lines.size}: #{out}")
  next unless lines.size == 3

  bodies = lines.map { JSON.parse(_1) }
  check.call(bodies.all? { _1["jsonrpc"] == "2.0" }, "not json-rpc: #{bodies}")
  first = bodies[0]
  check.call(first["id"] == 1, "first id #{first["id"]}")
  text = first.dig("result", "content", 0, "text").to_s
  check.call(text.include?("status:"), "run_ruby did not return a tool result: #{first}")
  check.call(text.valid_encoding?, "tool result is not valid UTF-8")
  second = bodies[1]
  check.call(second["id"] == 2 && second.dig("error", "code") == -32603, "expected JSON-RPC error, got #{second}")
  third = bodies[2]
  check.call(third["id"] == 3 && third["result"] == {}, "ping failed: #{third}")
end

exit(fail ? 1 : 0)
