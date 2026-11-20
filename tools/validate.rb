# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8

# Usage: ruby tools/validate.rb
# すべてのテスト入力が問題文の制約を満たしているかを確認します。

require "date"

ROOT = File.expand_path("..", __dir__)

def lines_of(s)
  raise "入力が改行で終わっていない" unless s.end_with?("\n")
  s.split("\n", -1)[0..-2]
end

def check(cond, msg) = (raise msg unless cond)

VALIDATORS = {
  "01" => ->(s) {
    ls = lines_of(s); check((1..20).cover?(ls.size), "m")
    ls.each { check(_1.match?(/\A\d+\z/) && (1..50).cover?(_1.to_i), "a_i=#{_1}") }
  },
  "02" => ->(s) {
    ls = lines_of(s); check(ls.size == 1 && ls[0].match?(/\A\d+\z/) && (1..60).cover?(ls[0].to_i), "n")
  },
  "03" => ->(s) {
    ls = lines_of(s); check((1..30).cover?(ls.size), "m")
    keys = ls.map do |v|
      check(v.match?(/\A\d{1,3}(\.\d{1,3}){0,3}\z/), "v=#{v}")
      k = v.split(".").map(&:to_i); k.pop while k.size > 1 && k[-1] == 0; k
    end
    check(keys.uniq.size == keys.size, "等しいバージョンがある")
  },
  "04" => ->(s) {
    ls = lines_of(s); check((1..30).cover?(ls.size), "m")
    ls.each do |l|
      check(l.match?(/\A\d{4}-\d\d-\d\d\z/), "形式 #{l}")
      d = Date.strptime(l, "%Y-%m-%d")
      check(d >= Date.new(1912, 7, 30) && d <= Date.new(2099, 12, 31), "範囲 #{l}")
    end
  },
  "05" => ->(s) {
    ls = lines_of(s); check((1..20).cover?(ls.size), "m")
    ls.each { check(_1.match?(/\A[a-z]{2,10}\z/), "w=#{_1}") }
  },
  "06" => ->(s) { ls = lines_of(s); check(ls.size == 1 && ls[0].match?(/\A\d{1,100}\z/), "s") },
  "07" => ->(s) {
    ls = lines_of(s); check((1..10).cover?(ls.size), "行数")
    ls.each { check(_1.match?(/\A[ -~]{1,40}\z/), "行 #{_1.inspect}") }
  },
  "08" => ->(s) {
    ls = lines_of(s); names = ls[0].split(" ", -1); n = names.size
    check((2..10).cover?(n) && names == ("A"..).first(n), "名前行")
    check((1..15).cover?(ls.size - 1), "h")
    ls[1..].each do |r|
      check(r.match?(/\A\|([- ]\|)*\z/) && r.size <= 2 * n - 1, "行 #{r.inspect}")
      check(!r.include?("|-|-"), "横線が連続")
    end
  },
  "09" => ->(s) { ls = lines_of(s); check((1..40).cover?(ls.size), "行数") },
  "10" => ->(s) {
    ls = lines_of(s); check((1..20).cover?(ls.size), "h")
    check(ls.map(&:size).uniq.size == 1 && (1..20).cover?(ls[0].size), "w")
    ls.each { check(_1.match?(/\A[#.]+\z/), "文字") }
  },
  # ---- Anybatross ----
  "ab01" => ->(s) {
    lines_of(s).each { n = _1.scan(/\X/).size; check(n >= 2 && n.even?, "書記素数 #{n}: #{_1}") }
  },
  "ab02" => ->(s) {
    lines_of(s).each do |l|
      check(l.match?(/\A[a-z]+( [a-z]+)*\z/), "形式 #{l}")
      k = (l.ord - "y".ord) % 26
      check(l.split[0].each_char.map { ((_1.ord - 97 - k) % 26 + 97).chr }.join == "yapc", "先頭が yapc でない: #{l}")
    end
  },
  "ab03" => ->(s) {
    ls = lines_of(s)
    re = %r{\A\S+ - - \[\d\d/\w{3}/\d{4}:(\d\d):(\d\d):\d\d \+0900\] "[^"]*" ([2-5]\d\d) \d+ "[^"]*" "[^"]*" \d+\z}
    ms = ls.map { |l| m = l.match(re); check(m, "形式 #{l}"); [m[1], m[2]] }
    check(ms.map(&:first).uniq.size == 1, "時が複数")
    check(ms.map(&:last) == ms.map(&:last).sort, "時刻順でない")
  },
  "ab04" => ->(s) {
    ops = %w[+ - * / % = != < > <= >= dup drop swap . cr if else then begin until]
    lines_of(s).each { check(ops.include?(_1) || _1.match?(/\A\d+\z/), "トークン #{_1}") }
  },
  "ab05" => ->(s) {
    lines_of(s).each { check(_1.match?(/\A[0-9A-Za-zぁ-んァ-ンー]+( [0-9A-Za-zぁ-んァ-ンー]+)+\z/), "行 #{_1}") }
  },
  "ab06" => ->(s) {
    ls = lines_of(s); check(ls.size.even? && (2..40).cover?(ls.size), "高さ")
    check(ls.map(&:size).uniq.size == 1 && ls[0].size.even? && (2..40).cover?(ls[0].size), "幅")
    ls.each { check(_1.match?(/\A[`#]+\z/), "文字") }
  },
  "ab07" => ->(s) { lines_of(s).each { check(_1.match?(/\A[^a-z\n]+\z/) && _1.ascii_only?, "行 #{_1.inspect}") } },
  "ab08" => ->(s) {
    ls = lines_of(s); check(ls.size == 1 && ls[0].match?(/\A[a-z]+( [a-z]+)*\z/), "形式")
  },
}

ok = true
Dir[File.join(ROOT, "private", "*", "tests", "*.in"), File.join(ROOT, "problems", "*", "samples", "*.in")].sort.each do |path|
  id = path[%r{/([^/-]+)-[^/]*/(tests|samples)/}, 1]
  VALIDATORS.fetch(id).(File.read(path))
rescue => e
  ok = false
  puts "NG #{path.delete_prefix(ROOT + "/")}: #{e.message}"
end
puts ok ? "all inputs valid" : "invalid inputs found"
exit ok
