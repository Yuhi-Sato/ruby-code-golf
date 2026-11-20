# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8

# Usage: ruby tools/gen_anybatross_tests.rb [repo_root]
#
# 過去の Anybatross（カヤック主催、YAPC 併催のコードゴルフ）8問の非公開テストを生成します。
# 公式のテストケースは公開されていないため、問題文と公式の入出力例をもとに参照実装を書き、
# テスト入力を自作しています。
#
# 方針:
# - 公式の入出力例は official*.in / official*.out としてそのまま入れ、参照実装が再現できることを確認する
# - 問題文の解釈が分かれる箇所は、どの解釈でも同じ出力になる入力だけを採用する（各問題の「解釈」参照）

require "fileutils"

ROOT = File.expand_path(ARGV[0] || File.join(__dir__, ".."))
RNG = Random.new(20261121)

def lines(a) = a.join("\n") + "\n"

def write_cases(slug, cases)
  dir = File.join(ROOT, "private", slug, "tests")
  FileUtils.rm_rf(dir)
  FileUtils.mkdir_p(dir)
  cases.each do |name, input, output|
    File.write(File.join(dir, "#{name}.in"), input)
    File.write(File.join(dir, "#{name}.out"), output)
  end
  puts "#{slug}: #{cases.size} cases"
end

def check_official(slug, input, expected, actual)
  raise "#{slug}: 公式例を再現できません\nexpected: #{expected.inspect}\nactual:   #{actual.inspect}" unless expected == actual
end

def numbered(prefix, inputs, &ref) = inputs.each_with_index.map { |inp, i| [format("%s%02d", prefix, i + 1), inp, ref.(inp)] }

# ---------------------------------------------------------------------------
# ab01 Split of Grapheme (YAPC::Hiroshima 2024 Hole 1)
# 各行を書記素クラスタ単位で奇数番目・偶数番目に分け、空白区切りで出力する。
# ---------------------------------------------------------------------------
split_grapheme = ->(inp) {
  lines(inp.split("\n").map do |l|
    g = l.scan(/\X/)
    "#{g.each_slice(2).map(&:first).join} #{g.each_slice(2).map(&:last).join}"
  end)
}
interleave = ->(a, b) { a.scan(/\X/).zip(b.scan(/\X/)).flatten.join }
GRAPHEME_PAIRS = [
  %w[ruby perl], %w[yapc golf], %w[パトカー タクシー], %w[ふくおか はこだて],
  ["がくせい", "だいがく"],          # 濁点を結合文字で書いたもの
  ["café", "naïf"],                  # 結合アクセント
  ["👨‍👩‍👧🍣", "🏃🏽‍♀️🍜"],                         # ZWJ 合字・肌の色
  ["🇯🇵🇺🇸", "🏳️‍🌈🇫🇷"],                           # 国旗
  %w[漢字 かな], %w[a b], %w[Hello World],
].freeze
gpool = %w[a b c x y z ア イ ウ ン ー 字 😀 👍🏽 🇯🇵 👨‍👩‍👧] + ["é", "が"]
rand_word = ->(n) { Array.new(n) { gpool.sample(random: RNG) }.join }
ab01 = []
official = "パタトクカシーー\n"
check_official("ab01", official, "パトカー タクシー\n", split_grapheme.(official))
ab01 << ["official1", official, split_grapheme.(official)]
ab01 += numbered("case", [
  lines(GRAPHEME_PAIRS.map { interleave.(*_1) }),
  lines(Array.new(10) { n = RNG.rand(1..8); interleave.(rand_word.(n), rand_word.(n)) }),
  lines(Array.new(5) { n = RNG.rand(1..20); interleave.(rand_word.(n), rand_word.(n)) }),
], &split_grapheme)
write_cases("ab01-split-of-grapheme", ab01)

# ---------------------------------------------------------------------------
# ab02 The bombe (YAPC::Hiroshima 2024 Hole 2)
# 行ごとにずらし幅の違うシーザー暗号。各行の最初の単語は平文 "yapc"。
# ---------------------------------------------------------------------------
caesar = ->(s, k) { s.gsub(/[a-z]/) { ((_1.ord - 97 + k) % 26 + 97).chr } }
bombe = ->(inp) { lines(inp.split("\n").map { |l| caesar.(l, ("y".ord - l[0].ord) % 26) }) }
WORDS = %w[perl ruby python golf code hole par eagle birdie bogey fukuoka hiroshima hakodate
           conference talk speaker lightning sponsor booth coffee night party hello world
           the quick brown fox jumps over lazy dog zebra quiz xylophone].freeze
sentence = -> { (["yapc"] + Array.new(RNG.rand(0..8)) { WORDS.sample(random: RNG) }).join(" ") }
ab02 = numbered("case", [
  lines([[0, "yapc is fun"], [1, "yapc hiroshima"], [25, "yapc zzz aaa"], [13, "yapc"]].map { |k, s| caesar.(s, k) }),
  lines(Array.new(10) { caesar.(sentence.(), RNG.rand(26)) }),
  lines(Array.new(26) { |k| caesar.(sentence.(), k) }),
], &bombe)
write_cases("ab02-the-bombe", ab02)

# ---------------------------------------------------------------------------
# ab03 Apache's Call (YAPC::Hiroshima 2024 Hole 3)
# 解釈（実際に AC した参加者の記録に合わせる）:
# - タイムスタンプの「分」ごとにまとめる。行は時系列順で、テストは1時間の中に収める
# - その分の 5xx が 10 件を超えたら、その分の行は出力せずに打ち切る
# - リクエストの無い分は出力しない
# ---------------------------------------------------------------------------
apache = ->(inp) {
  out = []
  inp.split("\n").chunk { _1[/:(\d\d):\d\d \+/, 1] }.each do |_, ls|
    c = [0, 0, 0, 0]
    ls.each { c[_1[/" (\d)\d\d \d+ "/, 1].to_i - 2] += 1 }
    break if c[3] > 10

    out << c.join(" ")
  end
  out.empty? ? "" : lines(out)
}
UAS = ["Mozilla/4.08 [en] (Win98; I ;Nav)", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
       "curl/8.4.0", "Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) Mobile/15E148", "Go-http-client/1.1"].freeze
PATHS = ["/", "/challenge/9", "/contest/2024hiroshima", "/api/v1/submit?id=200", "/static/app.js", "/ranking?page=3"].freeze
REFS = ["-", "https://perlbatross.kayac.com/", "https://yapcjapan.org/2024hiroshima/", "https://www.google.com/search?q=500+error"].freeze
log_line = ->(min, sec, status) {
  ip = Array.new(4) { RNG.rand(1..254) }.join(".")
  meth = %w[GET GET GET POST HEAD].sample(random: RNG)
  "#{ip} - - [10/Feb/2024:15:#{format("%02d", min)}:#{format("%02d", sec)} +0900] \"#{meth} #{PATHS.sample(random: RNG)} HTTP/1.1\" " \
    "#{status} #{RNG.rand(0..99_999)} \"#{REFS.sample(random: RNG)}\" \"#{UAS.sample(random: RNG)}\" #{RNG.rand(100..2_000_000)}"
}
STATUSES = { 2 => [200, 201, 204], 3 => [301, 302, 304], 4 => [400, 403, 404, 429], 5 => [500, 502, 503, 504] }.freeze
# minutes: [[分, [2xx, 3xx, 4xx, 5xx]], ...] から時系列順のログを作る
make_log = ->(minutes) {
  out = []
  minutes.each do |min, counts|
    reqs = counts.each_with_index.flat_map { |n, i| Array.new(n) { STATUSES[i + 2].sample(random: RNG) } }.shuffle(random: RNG)
    secs = Array.new(reqs.size) { RNG.rand(60) }.sort
    reqs.zip(secs).each { |st, s| out << log_line.(min, s, st) }
  end
  lines(out)
}
rand_counts = ->(max5) { [RNG.rand(0..15), RNG.rand(0..5), RNG.rand(0..5), RNG.rand(0..max5)] }
ab03 = numbered("case", [
  make_log.([[16, [3, 1, 1, 0]], [17, [2, 0, 0, 1]], [20, [0, 0, 2, 0]]]),
  make_log.([[0, [5, 1, 0, 10]], [1, [1, 0, 0, 10]], [2, [4, 2, 1, 3]]]),          # 10件ちょうどは止まらない
  make_log.([[5, [4, 0, 1, 2]], [6, [1, 1, 1, 11]], [7, [9, 9, 9, 9]]]),           # 11件で打ち切り
  make_log.([[30, [0, 0, 0, 0]].tap { _1[1][0] = 1 }, [31, [0, 0, 0, 15]], [32, [3, 0, 0, 0]]]),
  make_log.(Array.new(20) { |i| [10 + i * 2, rand_counts.(8)] }.reject { _1[1].sum.zero? }),
  make_log.(Array.new(15) { |i| [i * 3, rand_counts.(i < 12 ? 9 : 20)] }.reject { _1[1].sum.zero? }),
], &apache)
write_cases("ab03-apaches-call", ab03)

# ---------------------------------------------------------------------------
# ab04 Pytecode (YAPC::Hiroshima 2024 Hole 4)
# 解釈（実際に AC した参加者の実装に合わせる）:
# - 二項演算は「下の値 演算子 上の値」。if / until は判定に使った値を取り除く
# - . は区切りなしで出力。cr で改行
# 曖昧さを避けるため、テストのプログラムは次を守る:
# - 割り算は割り切れるものだけ、% は左が0以上で右が正のものだけ
# - if / until が受け取る値は 0 か 1 だけ。if の分岐の中に if を入れない
# ---------------------------------------------------------------------------
class Pytecode
  OPS = %w[+ - * / % = != < > <= >= dup drop swap . cr if else then begin until].freeze
  def initialize(tokens) = (@t = tokens; @s = []; @out = +"")

  def run
    exec_block(0, @t.size)
    @out
  end

  # [from, to) を実行する
  def exec_block(from, to)
    i = from
    while i < to
      tok = @t[i]
      case tok
      when "+", "-", "*", "/", "%", "=", "!=", "<", ">", "<=", ">="
        b = @s.pop; a = @s.pop
        raise "割り切れない除算" if tok == "/" && (b.zero? || a % b != 0)
        raise "負の剰余" if tok == "%" && (a.negative? || b <= 0)
        @s << case tok
              when "+" then a + b
              when "-" then a - b
              when "*" then a * b
              when "/" then a / b
              when "%" then a % b
              when "=" then a == b ? 1 : 0
              when "!=" then a != b ? 1 : 0
              when "<" then a < b ? 1 : 0
              when ">" then a > b ? 1 : 0
              when "<=" then a <= b ? 1 : 0
              when ">=" then a >= b ? 1 : 0
              end
      when "dup" then @s << @s.last
      when "drop" then @s.pop
      when "swap" then @s[-2], @s[-1] = @s[-1], @s[-2]
      when "." then @out << @s.pop.to_s
      when "cr" then @out << "\n"
      when "if"
        el = (i...@t.size).find { @t[_1] == "else" }; th = (el...@t.size).find { @t[_1] == "then" }
        raise "if の中に if" if @t[(i + 1)...th].include?("if")
        c = @s.pop
        raise "if の条件が 0/1 でない: #{c}" unless [0, 1].include?(c)
        c == 1 ? exec_block(i + 1, el) : exec_block(el + 1, th)
        i = th
      when "begin"
        depth = 0; j = i
        loop do
          j += 1
          depth += 1 if @t[j] == "begin"
          break if @t[j] == "until" && depth.zero?
          depth -= 1 if @t[j] == "until"
        end
        steps = 0
        loop do
          exec_block(i + 1, j)
          c = @s.pop
          raise "until の値が 0/1 でない: #{c}" unless [0, 1].include?(c)
          break if c == 1
          raise "無限ループ" if (steps += 1) > 100_000
        end
        i = j
      else
        raise "不明なトークン #{tok}" unless tok.match?(/\A\d+\z/)
        @s << tok.to_i
      end
      i += 1
    end
  end
end
pytecode = ->(inp) { Pytecode.new(inp.split("\n")).run }
prog = ->(src) { lines(src.split) }
ab04 = numbered("case", [
  prog.("3 4 + . cr 10 3 - . cr 3 10 - . cr 6 7 * . cr 20 4 / . cr 17 5 % . cr"),
  prog.("1 2 swap . . cr 5 dup * . cr 9 8 drop . cr"),
  prog.("3 5 < . 5 3 < . 4 4 <= . 5 4 >= . 4 5 > . 7 7 = . 7 8 != . 7 7 != . cr"),
  prog.("5 3 > if 1 . else 0 . then 2 9 > if 1 . else 0 . then cr"),
  prog.("10 begin dup . cr 1 - dup 0 = until drop"),
  prog.("0 begin dup . 1 + dup 5 = until drop cr 100 7 - 3 * 9 / . cr"),
  prog.("1 begin dup 3 % 0 = if dup . cr else then 1 + dup 21 = until drop"),
  prog.("27 0 swap begin dup 2 % 0 = if 2 / else 3 * 1 + then swap 1 + swap dup 1 = until drop . cr"),
  prog.("3 begin 2 begin dup . 1 - dup 0 = until drop dup . cr 1 - dup 0 = until drop"),
], &pytecode)
write_cases("ab04-pytecode", ab04)

# ---------------------------------------------------------------------------
# ab05 Portalbress Gramana (YAPC::Hakodate 2024 Hole 1)
# 各行の単語がすべて互いにアナグラムなら 1、そうでなければ 0。
# 曖昧さを避けるため、各行の単語は2語以上にする。
# ---------------------------------------------------------------------------
anagram = ->(inp) { lines(inp.split("\n").map { |l| l.split(" ").map { _1.chars.sort }.uniq.size == 1 ? 1 : 0 }) }
official = "Perlbatross Portalbress\nパールバトロス パーストロバル ルバスロパトー\nPassw0rd Password\n"
check_official("ab05", official, "1\n1\n0\n", anagram.(official))
APOOL = [*"a".."z", *"A".."Z", *"0".."9", *"ぁ".."ん", *"ァ".."ン", "ー"].freeze
anagram_line = ->(ok) {
  base = Array.new(RNG.rand(1..10)) { APOOL.sample(random: RNG) }
  ws = Array.new(RNG.rand(2..5)) { base.shuffle(random: RNG).join }
  unless ok
    i = RNG.rand(ws.size)
    w = ws[i].chars
    case RNG.rand(3)
    when 0 then w[RNG.rand(w.size)] = APOOL.sample(random: RNG)
    when 1 then w << APOOL.sample(random: RNG)
    else w.delete_at(RNG.rand(w.size)) if w.size > 1
    end
    ws[i] = w.join
  end
  ws.join(" ")
}
ab05 = [["official1", official, anagram.(official)]] + numbered("case", [
  lines(["ruby ybur", "Ruby ruby", "listen silent enlist", "いるか かるい", "コード ドーコ", "12345 54321 15243", "0O O0", "aab abb"]),
  lines(Array.new(20) { anagram_line.(RNG.rand < 0.5) }),
  lines(Array.new(30) { anagram_line.(RNG.rand < 0.5) }),
], &anagram)
write_cases("ab05-portalbress", ab05)

# ---------------------------------------------------------------------------
# ab06 QuAArterPix (YAPC::Hakodate 2024 Hole 2)
# ` と # のアートを 2x2 ごとに多数決で縮小。同数なら左上の記号。
# ---------------------------------------------------------------------------
quarter = ->(inp) {
  g = inp.split("\n")
  lines(g.each_slice(2).map do |r0, r1|
    (0...r0.size).step(2).map do |x|
      b = [r0[x], r0[x + 1], r1[x], r1[x + 1]]
      h = b.count("#")
      h > 2 ? "#" : h < 2 ? "`" : b[0]
    end.join
  end)
}
OFFICIAL6 = [
  ["``\n``\n", "`\n"], ["`#\n##\n", "#\n"], ["`#\n`#\n", "`\n"], ["#`\n`#\n", "#\n"], ["``##\n``##\n", "`#\n"],
  ["```##```\n``####``\n`######`\n########\n########\n`######`\n``####``\n```##```\n", "`##`\n####\n####\n`##`\n"],
].freeze
ab06 = OFFICIAL6.each_with_index.map do |(i, o), k|
  check_official("ab06", i, o, quarter.(i))
  ["official#{k + 1}", i, o]
end
rgrid = ->(h, w, p) { lines(Array.new(h) { Array.new(w) { RNG.rand < p ? "#" : "`" }.join }) }
ab06 += numbered("case", [rgrid.(2, 2, 0.5), rgrid.(4, 10, 0.5), rgrid.(10, 4, 0.3), rgrid.(16, 32, 0.5), rgrid.(20, 40, 0.7)], &quarter)
write_cases("ab06-quaarterpix", ab06)

# ---------------------------------------------------------------------------
# ab07 Counter Counter (YAPC::Fukuoka 2025 Hole 1)
# 各行のカウンター（文字の中の閉じた空間）の数を「累計,その行の数」で出力。記号は数えない。
# ---------------------------------------------------------------------------
COUNTERS = { "0" => 1, "4" => 1, "6" => 1, "8" => 2, "9" => 1, "A" => 1, "B" => 2, "D" => 1,
             "O" => 1, "P" => 1, "Q" => 1, "R" => 1 }.freeze
counter = ->(inp) {
  total = 0
  lines(inp.split("\n").map { |l| n = l.chars.sum { COUNTERS.fetch(_1, 0) }; "#{total += n},#{n}" })
}
off1 = "KAYAC\nYAPC FUKUOKA\nWHITE\nPOWAWA\n*STRONG*: ZERO\n"
off2 = "SNAKE CASE\nWHITE SPACE\nITERATOR\nTOKEN GENERATION\nCOMPILE ERROR\nHASH MAP\n2025 NOVEMBER\n"
check_official("ab07", off1, "2,2\n6,4\n6,0\n10,4\n14,4\n", counter.(off1))
check_official("ab07", off2, "2,2\n4,2\n8,4\n12,4\n18,6\n21,3\n26,5\n", counter.(off2))
CPOOL = [*"0".."9", *"A".."Z"].freeze
SYMS = " *:!?-.,@#&%$()[]{}/'\"+=_~^|<>;".chars.freeze
cline = -> { Array.new(RNG.rand(1..40)) { RNG.rand < 0.75 ? CPOOL.sample(random: RNG) : SYMS.sample(random: RNG) }.join }
ab07 = [["official1", off1, counter.(off1)], ["official2", off2, counter.(off2)]] + numbered("case", [
  lines(["0123456789", "ABCDEFGHIJKLMNOPQRSTUVWXYZ", "@#&%$ ()[]{}", "8888 BBBB", "1235 7CEF"]),
  lines(Array.new(30) { cline.() }),
  lines(Array.new(100) { cline.() }),
], &counter)
write_cases("ab07-counter-counter", ab07)

# ---------------------------------------------------------------------------
# ab08 BPEagle (YAPC::Fukuoka 2025 Hole 2)
# 単語内の隣り合う2文字の組で最も多いものを A, B, C, ... に置き換えることを、最多の組が1回になるまで繰り返す。
# 解釈が分かれる点:
# - "aaa" の中の "aa" を2回と数えるか1回と数えるか
# 両方の数え方で同じ出力になる入力だけを採用する。同数なら文中で先に現れる組を選ぶ。
# ---------------------------------------------------------------------------
bpe = ->(inp, overlap:) {
  ws = inp.split(" ")
  dict = []
  ("A".."Z").each do |k|
    cnt = Hash.new(0)
    ws.each do |w|
      if overlap
        w.chars.each_cons(2) { cnt[_1.join] += 1 }
      else
        w.chars.each_cons(2).map(&:join).uniq.each { |pr| cnt[pr] += w.scan(pr).size }
      end
    end
    best, n = cnt.max_by { |_, v| v } # max_by は同数なら先に入ったもの（＝先に現れた組）を返す
    break if n.nil? || n < 2

    dict << "#{k}:#{best}"
    ws = ws.map { _1.gsub(best, k) }
  end
  "#{dict.join(",")}\n#{ws.join(" ")}\n"
}
official = "launchpad launchsite launchcrew\n"
check_official("ab08", official, "A:la,B:Au,C:Bn,D:Cc,E:Dh\nEpad Esite Ecrew\n", bpe.(official, overlap: true))
SYL = %w[la un ch pa d si te cr ew ba na ra ma ki to ru by pe rl go lf e o i a].freeze
bpe_input = ->(nw, ns) {
  loop do
    s = Array.new(nw) { Array.new(RNG.rand(1..ns)) { SYL.sample(random: RNG) }.join }.join(" ") + "\n"
    a = bpe.(s, overlap: true)
    next unless a == bpe.(s, overlap: false) && !a.start_with?("\n") && a.lines[0].count(",") < 25

    return s
  end
}
ab08 = [["official1", official, bpe.(official, overlap: true)]]
ab08 += numbered("case", [
  "banana bandana cabana\n", "mississippi missouri\n", "abc abd abe xyz\n",
  bpe_input.(4, 3), bpe_input.(8, 4), bpe_input.(15, 5), bpe_input.(30, 6),
].map { |s| s.tap { raise "解釈で出力が変わる: #{s}" unless bpe.(s, overlap: true) == bpe.(s, overlap: false) } }) { bpe.(_1, overlap: true) }
write_cases("ab08-bpeagle", ab08)
