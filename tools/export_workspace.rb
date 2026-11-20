# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8

# Usage: ruby tools/export_workspace.rb <problem> <dest> [--show-target] [--run-dir=<dir>]
#   e.g. ruby tools/export_workspace.rb 01 /tmp/golf-ws-01
#
# エージェントに渡す作業ディレクトリを作ります。中に入るのは公開してよいものだけです。
#
#   <dest>/PROBLEM.md     問題文（--show-target を付けると目標バイト数を追記）
#   <dest>/CONDITIONS.md  競技条件
#   <dest>/samples/       公開サンプル
#   <dest>/judge          採点用のラッパー（./judge answer.rb。非公開テストは通過数だけ）
#
# エージェントを起動するための設定は、作業ディレクトリの外（既定: <dest>-claude/）に書きます。
#   <run-dir>/settings.json  権限設定（Bash 禁止、作業ディレクトリ外の読み書き禁止）。--settings で渡す
#   <run-dir>/golf-mcp.json  MCP 設定（judge / run_ruby ツール）。--mcp-config で渡す
# 作業ディレクトリ内の .claude/settings.json は、信頼していないディレクトリでは allow が無視されるため使いません。
#
# 非公開テストと参考解はコピーしません。ラッパーと MCP サーバーはこのリポジトリのものを呼ぶだけです。

require "fileutils"
require "rbconfig"
require "json"
require "yaml"

ROOT = File.expand_path("..", __dir__)

args = ARGV.reject { _1.start_with?("--") }
show_target = ARGV.include?("--show-target")
problem, dest = args
abort "Usage: ruby tools/export_workspace.rb <problem> <dest> [--show-target] [--run-dir=<dir>]" unless problem && dest
dest = File.expand_path(dest)
run_dir = File.expand_path(ARGV.find { _1.start_with?("--run-dir=") }&.split("=", 2)&.last || "#{dest}-claude")

src = Dir[File.join(ROOT, "problems", "#{problem}*")].first
abort "No such problem: #{problem}" unless src
abort "#{dest} already exists and is not empty" if File.exist?(dest) && !Dir.empty?(dest)

meta = YAML.safe_load_file(File.join(src, "problem.yml"))
FileUtils.mkdir_p(dest)

statement = File.read(File.join(src, "README.md"))
statement += "\n## 目標\n\n#{meta["target_bytes"]} bytes 以下を目指してください。\n" if show_target
File.write(File.join(dest, "PROBLEM.md"), statement)
FileUtils.cp(File.join(ROOT, "CONDITIONS.md"), dest)
FileUtils.cp_r(File.join(src, "samples"), dest)

judge = File.join(dest, "judge")
File.write(judge, <<~SH)
  #!/bin/sh
  # 採点: ./judge answer.rb
  # 非公開テストは通過数だけ返す。--agent は --json / --verbose より優先される。
  exec ruby #{File.join(ROOT, "bin", "judge").dump} #{meta["id"].dump} --agent "$@"
SH
FileUtils.chmod(0o755, judge)

# ---- エージェント用の Claude Code 設定 ----
repo = File.realpath(ROOT)
private_dir = File.realpath(ENV.fetch("GOLF_PRIVATE_DIR", File.join(ROOT, "private")))
abs = ->(path) { "/" + path } # Read/Edit ルールで絶対パスは "//" で始める
FileUtils.mkdir_p(run_dir)
run_dir = File.realpath(run_dir)
hidden = [repo, private_dir].uniq

settings = {
  "permissions" => {
    # allow に無いツールは確認なしで自動的に拒否する
    "defaultMode" => "dontAsk",
    "allow" => [
      "Read(./**)",
      "Edit(./**)",
      "Glob",
      "Grep",
      "mcp__golf__judge",
      "mcp__golf__run_ruby",
    ],
    "deny" => [
      # シェルは一切使わせない（cat などの読み取り専用コマンドは allow が無くても通るため、ツールごと禁止する）
      "Bash",
      "WebFetch",
      "WebSearch",
      "NotebookEdit",
      # リポジトリ（ジャッジ・非公開テスト・参考解）は読み書き禁止
      *hidden.flat_map { ["Read(#{abs.(_1)}/**)", "Edit(#{abs.(_1)}/**)"] },
      # 起動設定は書き換え禁止
      "Edit(#{abs.(run_dir)}/**)",
      # 競技条件・問題文・サンプルは書き換え禁止
      "Edit(./.claude/**)",
      "Edit(./CONDITIONS.md)",
      "Edit(./PROBLEM.md)",
      "Edit(./samples/**)",
      "Edit(./judge)",
    ],
  },
  "enableAllProjectMcpServers" => false,
}

mcp = {
  "mcpServers" => {
    "golf" => {
      "type" => "stdio",
      "command" => RbConfig.ruby,
      "args" => [File.join(repo, "tools", "golf_mcp.rb"), meta["id"], File.realpath(dest)],
      "env" => ENV.key?("GOLF_PRIVATE_DIR") ? { "GOLF_PRIVATE_DIR" => private_dir } : {},
    },
  },
}

File.write(File.join(run_dir, "settings.json"), JSON.pretty_generate(settings) + "\n")
File.write(File.join(run_dir, "golf-mcp.json"), JSON.pretty_generate(mcp) + "\n")

puts "exported #{meta["slug"]} to #{dest} (claude settings: #{run_dir})"
