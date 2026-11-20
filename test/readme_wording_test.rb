# frozen_string_literal: true

# README が、オリジナル10問を Perlbatross の5回分と書かないことを確認する。
#   ruby test/readme_wording_test.rb

text = File.read(File.expand_path("../README.md", __dir__), encoding: "UTF-8")
fail = false
check = lambda do |cond, msg|
  next if cond

  warn "FAIL: #{msg}"
  fail = true
end

check.call(!text.include?("5回分"), "README still says 5 rounds")
check.call(!text.include?("Perlbatross（YAPC::Fukuoka 2025"), "README still describes the set as Perlbatross Fukuoka")
check.call(text.include?("オリジナル問題 10問"), "missing the 10 original problems")
check.call(text.include?("Anybatross"), "missing Anybatross")
%w[Perl Ruby Python JavaScript PHP].each do |lang|
  check.call(text.include?(lang), "missing language #{lang}")
end

exit(fail ? 1 : 0)
