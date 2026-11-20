# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8

# Usage: ruby tools/export_workspace.rb <problem> <dest> [--show-target]
#   e.g. ruby tools/export_workspace.rb 01 /tmp/golf-ws-01
#
# エージェントに渡す作業ディレクトリを作ります。中に入るのは公開してよいものだけです。
#
#   <dest>/PROBLEM.md     問題文（--show-target を付けると目標バイト数を追記）
#   <dest>/CONDITIONS.md  競技条件
#   <dest>/samples/       公開サンプル
#   <dest>/judge          採点用のラッパー（./judge answer.rb）
#
# 非公開テストと参考解はコピーしません。ラッパーはこのリポジトリの bin/judge を呼ぶだけです。

require "fileutils"
require "yaml"

ROOT = File.expand_path("..", __dir__)

args = ARGV.reject { _1.start_with?("--") }
show_target = ARGV.include?("--show-target")
problem, dest = args
abort "Usage: ruby tools/export_workspace.rb <problem> <dest> [--show-target]" unless problem && dest

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
  exec ruby #{File.join(ROOT, "bin", "judge").dump} #{meta["id"].dump} "$@"
SH
FileUtils.chmod(0o755, judge)

puts "exported #{meta["slug"]} to #{dest}"
