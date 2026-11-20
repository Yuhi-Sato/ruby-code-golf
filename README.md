# Ruby Code Golf

Ruby で解く、コードゴルフ（できるだけ短いコードで解く競技）のオリジナル問題集です。
YAPC のコードゴルフ企画 Perlbatross（YAPC::Fukuoka 2025 は2問）の5回分、10問を収録しています。

## 問題

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

## ルール

- Ruby 3.3 以上で動くこと。
- 入力は標準入力から読み、答えは標準出力に書くこと。入出力の文字コードは UTF-8 です。
- 入力は必ず改行で終わります。
- 外部コマンドの実行（`` ` ``、`system`、`exec`、`IO.popen` など）とネットワークアクセスは禁止。
- gem の `require` は禁止（標準ライブラリはOK。ただし `require` 文もバイト数に含みます）。
- スコアは解答ファイルのバイト数です（末尾の改行1つは数えません）。少ないほど良い。全角文字は3バイトです。
- 出力の比較では、各行末の空白と出力末尾の改行は無視します。
- 1ケースあたりの制限時間は5秒です。

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
- 解答は空の一時ディレクトリで、標準入力だけを渡して実行します。制限時間を超えるとプロセスごと止めます。

## エージェント評価用の作業ディレクトリ

```sh
ruby tools/export_workspace.rb 01 /tmp/golf-ws-01 [--show-target]
```

エージェントに見せてよいものだけを入れた作業ディレクトリを作ります。

```
/tmp/golf-ws-01/
├── PROBLEM.md      # 問題文（--show-target で目標バイト数を追記）
├── CONDITIONS.md   # 競技条件
├── samples/        # 公開サンプル
└── judge           # ./judge answer.rb で bin/judge を呼ぶラッパー
```

非公開テストと参考解はコピーしません。

**注意:** 今の時点では、解答プログラムはジャッジと同じユーザー権限で動きます。
そのため、解答が `private/` を直接読めば非公開テストを盗み見られます。
エージェントを回すときは、ランナー側で次のどちらかの対策が必要です（ステップ3で対応予定）。

- Claude Code の権限設定で、このリポジトリへのアクセスを `./judge` 以外すべて拒否する
- ジャッジを別ユーザーやサンドボックス（コンテナ、bubblewrap など）で動かし、解答から `private/` が見えないようにする

## 構成

```
.
├── CONDITIONS.md              # エージェント向けの競技条件
├── bin/judge                  # 採点スクリプト
├── problems/<問題>/           # 公開してよいもの
│   ├── README.md              #   問題文
│   ├── problem.yml            #   メタデータ（タイトル、難易度、目標バイト数）
│   └── samples/               #   公開サンプル（README の入出力例から生成）
├── private/<問題>/            # エージェントに見せないもの
│   ├── tests/                 #   非公開テスト (*.in / *.out)
│   └── solution.rb            #   参考解（ネタバレ）
└── tools/
    ├── gen_tests.rb           # 非公開テストを生成（読みやすい参照実装つき）
    ├── extract_samples.rb     # README の入出力例から samples/ を生成
    ├── validate.rb            # 全テスト入力が問題文の制約を満たすか確認
    └── export_workspace.rb    # エージェント用の作業ディレクトリを作る
```

## テストの作り直し

```sh
ruby tools/gen_tests.rb .
ruby tools/extract_samples.rb
ruby tools/validate.rb
```
