# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8
# Readable reference implementations for the original problem set.
require "date"
ROOT = ARGV[0]
srand(20261120)
def lines(a) = a.join("\n") + "\n"
def cases(dir, inputs)
  d = "#{ROOT}/private/#{dir}/tests"
  require "fileutils"; FileUtils.mkdir_p(d)
  names = []
  inputs.each_with_index do |inp, i|
    name = format("%02d", i + 1)
    names << name
    File.write("#{d}/#{name}.in", inp)
    File.write("#{d}/#{name}.out", yield(inp))
  end
  Dir.glob("#{d}/*.{in,out}").each do |path|
    base = File.basename(path).sub(/\.(in|out)\z/, "")
    File.delete(path) unless names.include?(base)
  end
end

# 01 正の字
cases("01-tally-marks", [lines([*1..10]), lines([11, 15, 23, 49, 50]), lines(Array.new(20) { rand(1..50) })]) do |inp|
  lines(inp.split.map { |l| n = l.to_i; "正" * (n / 5) + ["", "一", "丅", "下", "止"][n % 5] })
end

# 02 定規
cases("02-ruler", %w[1 5 9 10 23 45 50 60].map { _1 + "\n" }) do |inp|
  n = inp.to_i
  top = (0..n).map { |i| i % 10 == 0 ? "|" : i % 5 == 0 ? ":" : "." }.join
  bottom = (0..n).step(10).map { _1.to_s.ljust(10) }.join.rstrip
  lines([top, bottom])
end

# 03 バージョンソート
gen_versions = ->(k) {
  seen = {}; out = []
  while out.size < k
    v = Array.new(rand(1..4)) { [0, 0, 1, 2, 3, 9, 10, 11, 99, 100, rand(0..999)].sample }
    key = v.dup; key.pop while key.size > 1 && key[-1] == 0
    next if seen[key]
    seen[key] = 1; out << v.join(".")
  end
  out
}
cases("03-version-sort", [
  lines(%w[3.3.10 3.3.9 3.10.0 3.4 2.7.8]),
  lines(%w[1.0.0.1 1 0.9.99 1.0.1 0.10 0.9.100]),
  lines(%w[10 0.0.1 9.999.999.999 0 1.2.3.4 0.1 2]),
  lines(gen_versions.(30)),
]) { |inp| lines(inp.split.sort_by { _1.split(".").map(&:to_i) }) }

# 04 和暦
ERAS = [["令和", Date.new(2019, 5, 1)], ["平成", Date.new(1989, 1, 8)], ["昭和", Date.new(1926, 12, 25)], ["大正", Date.new(1912, 7, 30)]]
wareki = ->(s) {
  d = Date.parse(s); name, st = ERAS.find { |_, st| d >= st }
  y = d.year - st.year + 1
  "#{name}#{y == 1 ? "元" : y}年#{d.month}月#{d.day}日"
}
lo = Date.new(1912, 7, 30); hi = Date.new(2099, 12, 31)
cases("04-wareki", [
  lines(%w[2026-11-20 2019-05-01 2019-04-30 1989-01-08 1989-01-07]),
  lines(%w[2000-01-01 2010-10-10 1912-07-30 1912-12-31 1926-12-24 1926-12-25 1927-01-01 1988-12-31 1990-01-01 2020-01-01 2099-12-31]),
  lines(Array.new(30) { (lo + rand(hi - lo + 1)).iso8601 }),
]) { |inp| lines(inp.split.map(&wareki)) }

# 05 しりとり
shiritori = ->(ws) {
  seen = {}
  ws.each_with_index do |w, i|
    return i + 1 if i > 0 && w[0] != ws[i - 1][-1]
    return i + 1 if seen[w]
    return i + 1 if w.end_with?("n")
    seen[w] = 1
  end
  0
}
cases("05-shiritori", [
  lines(%w[sakura ame eki ika ari inu uta]),
  lines(%w[sushi ika asa kame]),
  lines(%w[neko okane eki ika ame eki]),
  lines(%w[kame ebi ishi inu udon]),
  lines(%w[tora ari ike eda asu uma ame emu kuma]),
  lines(%w[ramen]),
  lines(%w[sakura]),
  lines(%w[aa aa]),
  lines(%w[kame koban]),
  lines(%w[ao oi ia ai ii iu ue ea au uo oa ae eo oe ei ua aki iki eki iku]),
]) { |inp| "#{shiritori.(inp.split)}\n" }

# 06 数字ヒストグラム
cases("06-digit-histogram", [
  "31415926535\n", "0123456789\n", "7\n", "1111222330\n", "0000000000\n", "1234567890" * 10 + "\n", Array.new(100) { rand(10) }.join + "\n",
]) do |inp|
  c = (0..9).map { inp.count(_1.to_s) }
  lines(c.max.downto(1).map { |h| c.map { _1 >= h ? "#" : " " }.join.rstrip } + ["0123456789"])
end

# 07 鏡文字
MIRROR = { "(" => ")", ")" => "(", "[" => "]", "]" => "[", "{" => "}", "}" => "{", "<" => ">", ">" => "<",
           "/" => "\\", "\\" => "/", "b" => "d", "d" => "b", "p" => "q", "q" => "p" }
mirror = ->(inp) {
  ls = inp.chomp.split("\n", -1); w = ls.map(&:size).max
  lines(ls.map { |l| l.ljust(w).reverse.chars.map { MIRROR[_1] || _1 }.join.rstrip })
}
cases("07-mirror", [
  lines([" /\\_/\\", "( o.o )", " > ^ <"]),
  lines(["-->", "<==|", "[ok]"]),
  lines(["bdpq", "{[(<ruby>)]}", "pqbd db qp"]),
  lines(["    /\\", "   /  \\", "  /____\\", "  |    |", "  | [] |", "  |____|"]),
  lines(["YAPC", "  2026 :)"]),
  lines(["  <-- d", "     ", "b -->", "         ]"]),
]) { |inp| mirror.(inp) }

# 08 あみだくじ
amida = ->(inp) {
  ls = inp.split("\n"); a = ls[0].split
  ls[1..].each { |r| r.chars.each_with_index { |c, i| (k = i / 2; a[k], a[k + 1] = a[k + 1], a[k]) if c == "-" } }
  a.join(" ") + "\n"
}
gen_amida = ->(n, h) {
  rows = Array.new(h) do
    bars = []
    (n - 1).times { |k| bars << (rand < 0.4 && bars[-1] != true) }
    (0...n).map { "|" }.zip(bars.map { _1 ? "-" : " " }).flatten.compact.join.rstrip
  end
  lines([("A".ord...("A".ord + n)).map(&:chr).join(" ")] + rows)
}
cases("08-amidakuji", [
  lines(["A B C D", "|-| |-|", "| |-| |", "|-| | |", "| | |-|"]),
  lines(["A B", "| |", "|-|"]),
  lines(["A B C", "|-|", "| |-|", "|-|", "| |-|", "|-|", "| |-|"]),
  gen_amida.(6, 8), gen_amida.(10, 15), gen_amida.(8, 12),
  lines(["A B C D E F G H I J", "| | | | | | | | | |"]),
  lines(["A B C D E", "|-| |-| |", "| |-| |-|", "|-| |-| |", "| |-| |-|", "|-| |-| |"]),
]) { |inp| amida.(inp) }

# 09 Ruby インデント整形
indent = ->(inp) {
  lv = 0
  lines(inp.split("\n", -1)[0..-2].map do |raw|
    s = raw.strip
    d = s.match?(/\A(end|else|elsif|when|rescue|ensure)\b/) ? 1 : 0
    out = s.empty? ? "" : "  " * (lv - d) + s
    lv -= 1 if s.match?(/\Aend\b/)
    lv += 1 if s.match?(/\A(def|class|module|if|unless|while|until|case|begin)\b/) || s.match?(/\bdo( \|[^|]*\|)?\z/)
    out
  end)
}
scramble = ->(src) { lines(src.split("\n").map { |l| l.strip.empty? ? "" : " " * rand(0..6) + l.strip }) }
cases("09-ruby-indent", [
  scramble.(<<~'R'),
    def hello(name)
      puts "Hello, #{name}!"
    end
  R
  scramble.(<<~'R'),
    class Greeter
      def initialize(names)
        @names = names
      end

      def greet
        @names.each do |name|
          if name.empty?
            next
          elsif name == "Matz"
            puts "Thank you, #{name}"
          else
            puts "Hi, #{name}"
          end
        end
      end
    end
  R
  scramble.(<<~'R'),
    module YAPC
      def self.score(code)
        case code.size
        when 0..50
          :eagle
        when 51..100
          :birdie
        else
          :bogey
        end
      end
    end
  R
  scramble.(<<~'R'),
    begin
      i = 0
      while i < 3
        3.times do |j|
          puts i * j unless j.zero?
        end
        i += 1
      end
    rescue => e
      warn e.message
    ensure
      puts "done"
    end
  R
  scramble.(<<~'R'),
    endpoint = "/api"
    if_flag = true
    doc = "do"
    unless endpoint.empty?
      until if_flag
        if_flag = [1, 2].map { |x| x * 2 }.any?
      end
      [3, 4].each_with_index do |a, b|
        p a, b
      end
    end

    case doc
    when "do"
      puts "ok"
    end
  R
  # rand は呼ばない（このあとの問題の乱数がずれないように）。
  # 行末の undo / todo は単語の do ではない。do$ では誤って段を増やす。
  lines([
    "  def run(items)",
    "x = undo",
    "    todo",
    " items.each do |x|",
    "p x",
    "   end",
    "  y = 1",
    " end",
  ]),
]) { |inp| indent.(inp) }

# 10 罫線
BOX = "■│││─┘┐┤─└┌├─┴┬┼"
box = ->(inp) {
  g = inp.split("\n"); h = g.size; w = g[0].size
  at = ->(y, x) { y >= 0 && x >= 0 && y < h && x < w && g[y][x] == "#" }
  lines(g.each_index.map { |y| (0...w).map { |x|
    next " " unless at.(y, x)
    BOX[(at.(y - 1, x) ? 1 : 0) + (at.(y + 1, x) ? 2 : 0) + (at.(y, x - 1) ? 4 : 0) + (at.(y, x + 1) ? 8 : 0)]
  }.join.rstrip })
}
rgrid = ->(h, w) { lines(Array.new(h) { Array.new(w) { rand < 0.5 ? "#" : "." }.join }) }
cases("10-box-drawing", [
  lines(%w[#####. #.#.#. #####. ......  ....#.]),
  lines(%w[#]),
  lines(%w[.#.. ###. .#.# ...#]),
  lines(%w[######## #......# #.####.# #.#..#.# #.####.# #......# ########]),
  rgrid.(10, 15), rgrid.(20, 20),
  lines(%w[.... .... ....]),
  lines(["#" * 20]),
  lines(["#"] * 20),
  lines(%w[##. ##. ..#]),
]) { |inp| box.(inp) }
