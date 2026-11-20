# frozen_string_literal: true

# `do$` は undo / todo を do とみなして 09 の新しい非公開テストに落ちる。
# 単語境界の参考解は通り、パーは 184 のまま。
#   ruby test/ruby_indent_do_word_test.rb

require "json"
require "open3"
require "rbconfig"
require "tmpdir"
require "yaml"

ROOT = File.expand_path("..", __dir__)
fail = false
check = lambda do |cond, msg|
  next if cond

  warn "FAIL: #{msg}"
  fail = true
end

statement = File.read(File.join(ROOT, "problems/09-ruby-indent/README.md"), encoding: "UTF-8")
check.call(statement.include?("undo") && statement.include?("todo"), "rule 4 does not mention undo/todo")

readme = File.read(File.join(ROOT, "README.md"), encoding: "UTF-8")
meta = YAML.safe_load_file(File.join(ROOT, "problems/09-ruby-indent/problem.yml"))
solution = File.binread(File.join(ROOT, "private/09-ruby-indent/solution.rb")).delete_suffix("\n")
check.call(solution.bytesize == 184 && meta["target_bytes"] == 184, "par drifted: bytes=#{solution.bytesize} yml=#{meta["target_bytes"]}")
check.call(readme.include?("| 184 bytes |") || readme.include?("184 bytes"), "README table lost 184")

hidden = File.read(File.join(ROOT, "private/09-ruby-indent/tests/06.in"), encoding: "UTF-8")
check.call(hidden.include?("undo") && hidden.include?("todo"), "hidden case 06 lost undo/todo")

def judge(path)
  out, err, status = Open3.capture3(
    { "GOLF_SANDBOX" => "off" },
    RbConfig.ruby, File.join(ROOT, "bin", "judge"), "09", path, "--json",
  )
  [JSON.parse(out), err, status]
end

body, err, status = judge(File.join(ROOT, "private/09-ruby-indent/solution.rb"))
check.call(status.success? && body["accepted"] && body["bytes"] == 184, "reference failed: #{body} #{err}")

Dir.mktmpdir("golf-indent") do |dir|
  bad_path = File.join(dir, "bad.rb")
  File.write(bad_path, solution.sub('\bdo', "do"))
  body, err, status = judge(bad_path)
  failed = body["cases"].select { _1["status"] != "accepted" }.map { _1["name"] }
  check.call(!status.success? && failed == ["06"], "do$ answer should fail only 06, got #{failed}: #{body} #{err}")
end

exit(fail ? 1 : 0)
