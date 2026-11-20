# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8

# Usage: ruby tools/extract_samples.rb
# 各問題の README.md の「入出力例」から公開サンプル (problems/<id>/samples/*.in, *.out) を作ります。

require "fileutils"

ROOT = File.expand_path("..", __dir__)
PATTERN = /入力:\n\n```\n(.*?)```\n\n出力:\n\n```\n(.*?)```/m

Dir[File.join(ROOT, "problems", "*", "README.md")].sort.each do |readme|
  dir = File.dirname(readme)
  pairs = File.read(readme).scan(PATTERN)
  abort "#{readme}: 入出力例が見つかりません" if pairs.empty?

  FileUtils.rm_rf(File.join(dir, "samples"))
  FileUtils.mkdir_p(File.join(dir, "samples"))
  pairs.each_with_index do |(input, output), i|
    name = format("sample%d", i + 1)
    File.write(File.join(dir, "samples", "#{name}.in"), input)
    File.write(File.join(dir, "samples", "#{name}.out"), output)
  end
  puts "#{File.basename(dir)}: #{pairs.size} sample(s)"
end
