# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8

# Usage: ruby tools/golf_mcp.rb <problem> <workspace>
#
# エージェントに渡す MCP サーバー（stdio）。Bash を禁止したエージェントは、この2つのツールだけで
# 解答を試して採点します。どちらも作業ディレクトリ内のファイルしか受け付けず、
# 解答はサンドボックス（lib/golf_sandbox.rb）の中で実行します。
#
#   judge     : 作業ディレクトリ内の解答ファイルを bin/judge で採点する
#   run_ruby  : 作業ディレクトリ内の Ruby ファイル、またはコード片を、与えた標準入力で実行する

require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require_relative "../lib/golf_sandbox"

PROBLEM, WORKSPACE = ARGV
abort "Usage: ruby tools/golf_mcp.rb <problem> <workspace>" unless PROBLEM && WORKSPACE
WS = File.realpath(WORKSPACE)
JUDGE = File.join(GolfSandbox::ROOT, "bin", "judge")
RUN_TIME_LIMIT = 5
MAX_OUTPUT = 4000

TOOLS = [
  {
    name: "judge",
    description: "解答ファイルを採点する。公開サンプルと非公開テストを実行し、全問正解ならバイト数をスコアとして返す。",
    inputSchema: {
      type: "object",
      properties: { file: { type: "string", description: "作業ディレクトリからの相対パス（既定: answer.rb）" } },
    },
  },
  {
    name: "run_ruby",
    description: "Ruby を実行して標準出力・標準エラー・終了状態を返す。file（作業ディレクトリ内の相対パス）か code のどちらかを指定する。実行時間は5秒まで、ネットワークとファイルの読み書きは制限される。",
    inputSchema: {
      type: "object",
      properties: {
        file: { type: "string", description: "実行するファイル（作業ディレクトリからの相対パス）" },
        code: { type: "string", description: "実行するコード片" },
        stdin: { type: "string", description: "標準入力に渡す文字列" },
      },
    },
  },
].freeze

class ToolError < StandardError; end

def workspace_file(rel)
  rel = rel.to_s.empty? ? "answer.rb" : rel.to_s
  raise ToolError, "相対パスで指定してください: #{rel}" if rel.start_with?("/", "~")

  path = File.expand_path(rel, WS)
  raise ToolError, "ファイルがありません: #{rel}" unless File.file?(path)

  real = File.realpath(path)
  raise ToolError, "作業ディレクトリの外は指定できません: #{rel}" unless real.start_with?(WS + "/")

  real
end

def clip(s) = s.size > MAX_OUTPUT ? s[0, MAX_OUTPUT] + "\n...(省略)" : s

def call_tool(name, args)
  case name
  when "judge"
    out, status = Open3.capture2e(RbConfig.ruby, JUDGE, PROBLEM, workspace_file(args["file"]))
    [out, !status.success?]
  when "run_ruby"
    input = args["stdin"].to_s
    status, out, err =
      if args["code"]
        GolfSandbox.run(["-e", args["code"].to_s], input, time_limit: RUN_TIME_LIMIT)
      else
        GolfSandbox.run_file(workspace_file(args["file"]), input, time_limit: RUN_TIME_LIMIT)
      end
    ["status: #{status}\n--- stdout\n#{clip(out)}\n--- stderr\n#{clip(err)}", false]
  else
    raise ToolError, "unknown tool: #{name}"
  end
rescue ToolError => e
  [e.message, true]
end

def reply(id, result: nil, error: nil)
  msg = { jsonrpc: "2.0", id: }
  error ? msg[:error] = error : msg[:result] = result
  $stdout.puts(JSON.generate(msg))
  $stdout.flush
end

$stdin.each_line do |line|
  next if line.strip.empty?

  req = JSON.parse(line)
  id = req["id"]
  next if id.nil? # notification

  case req["method"]
  when "initialize"
    reply(id, result: {
      protocolVersion: req.dig("params", "protocolVersion") || "2025-06-18",
      capabilities: { tools: {} },
      serverInfo: { name: "golf", version: "1.0.0" },
    })
  when "ping"
    reply(id, result: {})
  when "tools/list"
    reply(id, result: { tools: TOOLS })
  when "tools/call"
    text, is_error = call_tool(req.dig("params", "name"), req.dig("params", "arguments") || {})
    reply(id, result: { content: [{ type: "text", text: }], isError: is_error })
  else
    reply(id, error: { code: -32601, message: "Method not found: #{req["method"]}" })
  end
rescue JSON::ParserError => e
  reply(nil, error: { code: -32700, message: e.message })
end
