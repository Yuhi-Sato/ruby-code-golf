#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: ruby judge.rb <problem> <solution.rb>
#   e.g. ruby judge.rb 01 my_answer.rb
#
# 各テストケースの .in を標準入力に渡して解答を実行し、
# 標準出力が .out と一致するかを判定します。
# 比較時は各行末の空白と、出力末尾の改行を無視します。

require "open3"
require "timeout"

TIME_LIMIT = 5
ENV_UTF8 = { "LANG" => "C.UTF-8", "LC_ALL" => "C.UTF-8" }
Encoding.default_external = Encoding::UTF_8

def normalize(s) = s.dup.force_encoding(Encoding::UTF_8).scrub.lines.map(&:rstrip).join("\n").rstrip

def score(path)
  src = File.binread(path)
  src = src.delete_suffix("\n") # 末尾の改行1つはカウントしない
  src.bytesize
end

problem, solution = ARGV
abort "Usage: ruby judge.rb <problem> <solution.rb>" unless problem && solution
abort "No such file: #{solution}" unless File.exist?(solution)

dir = Dir[File.join(__dir__, "problems", "#{problem}*")].first
abort "No such problem: #{problem}" unless dir

cases = Dir[File.join(dir, "tests", "*.in")].sort
passed = 0

cases.each do |input_path|
  name = File.basename(input_path, ".in")
  expected = File.read(input_path.sub(/\.in\z/, ".out"))
  actual, err, status = Timeout.timeout(TIME_LIMIT) do
    Open3.capture3(ENV_UTF8, RbConfig.ruby, solution, stdin_data: File.read(input_path))
  end

  if status.success? && normalize(actual) == normalize(expected)
    passed += 1
    puts "  \e[32mPASS\e[0m #{name}"
  else
    puts "  \e[31mFAIL\e[0m #{name}"
    puts "    expected: #{normalize(expected).inspect[0, 200]}"
    puts "    actual:   #{normalize(actual).inspect[0, 200]}"
    puts "    stderr:   #{err.lines.first&.chomp}" unless err.empty?
  end
rescue Timeout::Error
  puts "  \e[31mTLE\e[0m  #{name}"
end

puts
puts "#{File.basename(dir)}: #{passed}/#{cases.size} passed"
if passed == cases.size
  puts "Score: #{score(solution)} bytes"
else
  exit 1
end
