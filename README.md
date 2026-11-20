# Ruby Code Golf

Ruby で解く、コードゴルフ（できるだけ短いコードで解く競技）の問題集です。次の2つのセットを収録しています。

- オリジナル問題 10問（YAPC のコードゴルフ企画の5回分を想定）
- 過去の Anybatross の問題 8問（問題文は書き直し、テストは自作、最短記録つき）

## オリジナル問題（10問）

| # | 問題 | 難易度 | パー |
| --- | --- | --- | --- |
| 01 | [正の字](problems/01-tally-marks/README.md) | ★☆☆ | 56 bytes |
| 02 | [定規](problems/02-ruler/README.md) | ★☆☆ | 69 bytes |
| 03 | [バージョンソート](problems/03-version-sort/README.md) | ★☆☆ | 39 bytes |
| 04 | [和暦](problems/04-wareki/README.md) | ★★☆ | 176 bytes |
| 05 | [しりとり審判](problems/05-shiritori/README.md) | ★★☆ | 75 bytes |
| 06 | [数字ヒストグラム](problems/06-digit-histogram/README.md) | ★★☆ | 97 bytes |
| 07 | [鏡文字](problems/07-mirror/README.md) | ★★☆ | 110 bytes |
| 08 | [あみだくじ](problems/08-amidakuji/README.md) | ★★☆ | 65 bytes |
| 09 | [Ruby インデント整形](problems/09-ruby-indent/README.md) | ★★★ | 184 bytes |
| 10 | [罫線化](problems/10-box-drawing/README.md) | ★★★ | 168 bytes |

「パー」は参考解（`private/<問題>/solution.rb`）のバイト数で、各問題の `problem.yml` の `target_bytes` と同じです。

## 過去の Anybatross の問題（8問）

カヤック主催のコードゴルフ大会 Anybatross（旧 Perlbatross。YAPC に合わせて開催）の過去問 8 問です。
問題文は元の問題をもとに書き直したもので、元の問題へのリンクを各問題に載せています。

| # | 問題 | 出典 | Par | 全言語最短 | Ruby 最短 | 参考解 (Ruby) |
| --- | --- | --- | --- | --- | --- | --- |
| ab01 | [Split of Grapheme](problems/ab01-split-of-grapheme/README.md) | Hiroshima 2024 Hole 1 | 105 | 51 (Perl, KarakasaDcFd) | なし | 64 |
| ab02 | [The bombe](problems/ab02-the-bombe/README.md) | Hiroshima 2024 Hole 2 | 105 | 38 (Perl, KarakasaDcFd) | なし | 63 |
| ab03 | [Apache's Call](problems/ab03-apaches-call/README.md) | Hiroshima 2024 Hole 3 | 190 | 101 (Perl, sugyan) | なし | 115 |
| ab04 | [Pytecode](problems/ab04-pytecode/README.md) | Hiroshima 2024 Hole 4 | 450 | 256 (Perl, KarakasaDcFd) | なし | 327 |
| ab05 | [Portalbress Gramana](problems/ab05-portalbress/README.md) | Hakodate 2024 Hole 1 | 100 | 64 (Perl, こーのいけ) | なし | 55 |
| ab06 | [QuAArterPix](problems/ab06-quaarterpix/README.md) | Hakodate 2024 Hole 2 | 105 | 70 (Perl, sugyan / こーのいけ) | なし | 135 |
| ab07 | [Counter Counter](problems/ab07-counter-counter/README.md) | Fukuoka 2025 Hole 1 | 100 | 45 (Perl, moznion) | 64 (mame) | 73 |
| ab08 | [BPEagle](problems/ab08-bpeagle/README.md) | Fukuoka 2025 Hole 2 | 250 | 102 (Ruby, nsfisis) | 102 (nsfisis) | 176 |

記録は大会サイトのランキングと[カヤックの講評記事](https://techblog.kayac.com/anybatross2025-editorial)によります（2026年11月時点）。
2024年の2大会は Perl のみの提出で、Ruby の記録はありません。各問題の `problem.yml` の `records` に同じ内容を入れています。

**注意:**

- **テストは自作です。** 公式の非公開テストは公開されていないため、問題文と公式の入出力例をもとに参照実装を書いてテストを作りました。公式の入出力例はすべてテストに入れてあり、参照実装はそれを再現します。テスト生成器（`tools/gen_anybatross_tests.rb`）とは別に書いた Ruby の参考解も、全テストに通ります。
- **記録とスコアはそのまま比べられません。** 記録は公式テストに対するものです。テストが違うので、ここで記録より短い解答が通っても、公式で通るとは限りません。
- **仕様をはっきりさせた問題があります。** 元の問題文で解釈が分かれる箇所は、実際に正解した参加者の記録に合わせたうえで、どの解釈でも答えが変わらない入力だけをテストに使っています。特に ab03（1分の区切り方と打ち切り）と ab04（演算の順や `if` の扱い）は、問題文に「元の問題との違い」を書いています。
- 参考解が記録より短いもの（ab05）は、テストが公式より甘い可能性があります。

## ルール

- Ruby 3.3 以上で動くこと。
- 入力は標準入力から読み、答えは標準出力に書くこと。入出力の文字コードは UTF-8 です。
- 入力は必ず改行で終わります。
- 外部コマンドの実行（`` ` ``、`system`、`exec`、`IO.popen` など）とネットワークアクセスは禁止。
- gem の `require` は禁止（標準ライブラリはOK。ただし `require` 文もバイト数に含みます）。
- スコアは解答ファイルのバイト数です（末尾の改行1つは数えません）。少ないほど良い。全角文字は3バイトです。
- 出力の比較では、各行末の空白と出力末尾の改行は無視します。
- 1ケースあたりの制限時間は5秒です。
- 標準出力または標準エラーが 4MB を超えると、その場で止めて `output_limit` とします。

## 採点

```sh
bin/judge 01 my_answer.rb            # 人間向けの表示
bin/judge 01 my_answer.rb --json     # ランナー向けの JSON
bin/judge 01 my_answer.rb --verbose  # 非公開テストの失敗内容も表示（管理者用）
```

```
  PASS sample1
  PASS hidden/01
  PASS hidden/02
  PASS hidden/03

01-tally-marks: 4/4 passed
Score: 56 bytes
```

- 公開サンプルが失敗したときは、期待出力と実際の出力を表示します。
- 非公開テストは、合否と失敗の種類（`wrong_answer` / `runtime_error` / `timeout`）だけを表示します。
- 解答はサンドボックスの中で、標準入力だけを渡して実行します。制限時間を超えるとプロセスごと止めます。出力が 4MB を超えたときも止め、状態は `output_limit` です。
- Linux は bubblewrap、macOS は sandbox-exec が必要です。無い場合は `GOLF_SANDBOX=off` で隔離なしで動かせます。

## エージェント評価用の作業ディレクトリ

```sh
ruby tools/export_workspace.rb 01 /tmp/golf-ws-01 [--show-target]
```

エージェントに見せてよいものだけを入れた作業ディレクトリを作ります。

```
/tmp/golf-ws-01/
├── PROBLEM.md              # 問題文（--show-target で目標バイト数を追記）
├── CONDITIONS.md           # 競技条件
├── samples/                # 公開サンプル
└── judge                   # 人間用の採点ラッパー（./judge answer.rb）

/tmp/golf-ws-01-claude/     # エージェントの起動設定（作業ディレクトリの外。--run-dir で変更可）
├── settings.json           # 権限設定（--settings で渡す）
└── golf-mcp.json           # MCP サーバー judge / run_ruby（--mcp-config で渡す）
```

非公開テストと参考解はコピーしません。

起動設定を作業ディレクトリの外に置くのは、Claude Code が「信頼していない作業ディレクトリ」の `.claude/settings.json` の allow を無視するためです（deny は効きます）。`--settings` で渡したファイルなら allow も deny も両方効くことを、デバッグログで確かめました。

### 隔離のしくみ

隔離は2段構えです。

1. **Claude Code の権限設定（`settings.json`）**
   - `defaultMode: dontAsk`：許可リストに無いツールは、確認なしで自動的に拒否します。
   - Bash は丸ごと禁止です。`cat` や `grep` などの読み取り専用コマンドは許可が無くても通ってしまうため、シェルそのものを使わせません。
   - 許可するのは、作業ディレクトリ内の Read / Edit / Glob / Grep と、MCP の `judge` / `run_ruby` だけです。
   - このリポジトリ（ジャッジ・非公開テスト・参考解）の読み書きは deny で明示的に禁止します。
   - 問題文・競技条件・サンプル・起動設定の書き換えも禁止します。
2. **解答の実行サンドボックス（`lib/golf_sandbox.rb`）**
   - エージェントが書いた解答は、Linux では bubblewrap、macOS では sandbox-exec の中で実行します。
   - リポジトリと非公開テストは見えず、ネットワークも使えません。
   - どちらのサンドボックスも無い環境では、黙って素で動かさずにエラーにします。手元で人間が試すときは `GOLF_SANDBOX=off` で外せます。
   - 非公開テストを読みに行く解答で確かめると、サンドボックスなしでは 4 ケース中 3 つが通りましたが、サンドボックスの中ではファイルが1つも見えませんでした。

MCP サーバー（`tools/golf_mcp.rb`）は作業ディレクトリ内のファイルしか受け付けず、`../` や絶対パス、外を指すシンボリックリンクは拒否します。

### 起動例（ステップ3のランナーで使う形）

```sh
cd /tmp/golf-ws-01
CLAUDE_CONFIG_DIR=/tmp/golf-claude-config \
claude -p "CONDITIONS.md と PROBLEM.md を読んで、judge に通る最短の解答を answer.rb に書いて" \
  --settings /tmp/golf-ws-01-claude/settings.json \
  --mcp-config /tmp/golf-ws-01-claude/golf-mcp.json --strict-mcp-config \
  --permission-mode dontAsk
```

`CLAUDE_CONFIG_DIR` を空のディレクトリに向けると、ふだんの設定・MCP・ログインは読み込まれません。
認証は `ANTHROPIC_API_KEY` か `CLAUDE_CODE_OAUTH_TOKEN`（`claude setup-token` で発行）で渡してください。

## 構成

```
.
├── CONDITIONS.md              # エージェント向けの競技条件
├── bin/judge                  # 採点スクリプト
├── lib/golf_sandbox.rb        # 解答を隔離して実行する（bubblewrap / sandbox-exec）
├── problems/<問題>/           # 公開してよいもの
│   ├── README.md              #   問題文
│   ├── problem.yml            #   メタデータ（タイトル、難易度、目標バイト数）
│   └── samples/               #   公開サンプル（README の入出力例から生成）
├── private/<問題>/            # エージェントに見せないもの
│   ├── tests/                 #   非公開テスト (*.in / *.out)
│   └── solution.rb            #   参考解（ネタバレ）
└── tools/
    ├── gen_tests.rb           # オリジナル10問の非公開テストを生成（読みやすい参照実装つき）
    ├── gen_anybatross_tests.rb # Anybatross 8問の非公開テストを生成
    ├── extract_samples.rb     # README の入出力例から samples/ を生成
    ├── validate.rb            # 全テスト入力が問題文の制約を満たすか確認
    ├── export_workspace.rb    # エージェント用の作業ディレクトリと権限設定を作る
    └── golf_mcp.rb            # エージェントに渡す MCP サーバー（judge / run_ruby）
```

## テストの作り直し

```sh
ruby tools/gen_tests.rb .
ruby tools/gen_anybatross_tests.rb .
ruby tools/extract_samples.rb
ruby tools/validate.rb
```
