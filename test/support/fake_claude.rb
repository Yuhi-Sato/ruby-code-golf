#!/usr/bin/env ruby
# frozen_string_literal: true

# bin/evaluate のテスト用。本物の Claude Code ではない。
# 作業ディレクトリに answer.rb を書き、stream-json を標準出力へ出す。
# FAKE_CLAUDE_MODE=timeout|silence|error で終了の仕方を変える。

require "json"

File.write("claude.argv.json", JSON.pretty_generate(ARGV) + "\n")

if (path = ENV["FAKE_CLAUDE_ANSWER_FILE"]) && File.file?(path)
  File.binwrite("answer.rb", File.binread(path))
elsif ENV["FAKE_CLAUDE_ANSWER"]
  File.write("answer.rb", ENV["FAKE_CLAUDE_ANSWER"])
end

events = [
  {
    "type" => "assistant",
    "message" => {
      "content" => [
        { "type" => "tool_use", "name" => "mcp__golf__judge", "input" => {} },
        { "type" => "tool_use", "name" => "mcp__golf__run_ruby", "input" => {} },
      ],
      "usage" => { "input_tokens" => 3, "output_tokens" => 1 },
    },
  },
  {
    "type" => "assistant",
    "message" => {
      "content" => [{ "type" => "tool_use", "name" => "mcp__golf__judge", "input" => {} }],
    },
  },
  {
    "type" => "result",
    "subtype" => "success",
    "usage" => {
      "input_tokens" => 100,
      "output_tokens" => 40,
      "cache_read_input_tokens" => 5,
      "cache_creation_input_tokens" => 2,
    },
  },
]

mode = ENV["FAKE_CLAUDE_MODE"]
if mode == "silence"
  puts JSON.generate(events.first)
  $stdout.flush
  sleep 60
elsif mode == "timeout"
  puts JSON.generate(events.last)
  $stdout.flush
  child = Process.fork { sleep 60 }
  sleep 60
  Process.wait(child) rescue nil
elsif mode == "error"
  warn "fake claude failed"
  exit 2
else
  puts "not json"
  events.each { puts JSON.generate(_1) }
  $stdout.flush
end
