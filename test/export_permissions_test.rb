# frozen_string_literal: true

# 生成する settings.json が Glob / Grep を作業ディレクトリに限定していることを確認する。
# Claude Code 自体はこの環境に無いので、ツールがパス制限を守るかは未検証。
#   ruby test/export_permissions_test.rb

require "json"
require "open3"
require "rbconfig"
require "tmpdir"

ROOT = File.expand_path("..", __dir__)
fail = false
check = lambda do |cond, msg|
  next if cond

  warn "FAIL: #{msg}"
  fail = true
end

Dir.mktmpdir("golf-export") do |dir|
  dest = File.join(dir, "ws")
  _out, err, status = Open3.capture3(RbConfig.ruby, File.join(ROOT, "tools", "export_workspace.rb"), "01", dest)
  check.call(status.success?, "export failed: #{err}")
  next unless status.success?

  run_dir = File.realpath("#{dest}-claude")
  settings = JSON.parse(File.read(File.join(run_dir, "settings.json")))
  allow = settings.dig("permissions", "allow")
  deny = settings.dig("permissions", "deny")
  check.call(allow.include?("Glob(./**)") && allow.include?("Grep(./**)"), "scoped allows missing: #{allow}")
  check.call(!allow.include?("Glob") && !allow.include?("Grep"), "bare Glob/Grep still allowed: #{allow}")
  repo = File.realpath(ROOT)
  # abs は "/" + 絶対パスなので、ルールは Read(//...) になる。
  check.call(deny.include?("Read(/#{repo}/**)"), "repo read deny missing: #{deny}")
  check.call(deny.include?("Read(/#{run_dir}/**)"), "settings dir is readable: #{deny}")
  check.call(deny.include?("Edit(/#{run_dir}/**)"), "settings dir is writable: #{deny}")
end

exit(fail ? 1 : 0)
