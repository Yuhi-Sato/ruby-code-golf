# Ruby Code Golf

Ruby で解く、コードゴルフ（できるだけ短いコードで解く競技）のオリジナル問題集です。
YAPC のコードゴルフ企画 Perlbatross（YAPC::Fukuoka 2025 は2問）の5回分、10問を収録しています。

## 問題

| # | 問題 | 難易度 | パー |
| --- | --- | --- | --- |
| 01 | [正の字](problems/01-tally-marks/README.md) | ★☆☆ | 77 bytes |
| 02 | [定規](problems/02-ruler/README.md) | ★☆☆ | 90 bytes |
| 03 | [バージョンソート](problems/03-version-sort/README.md) | ★☆☆ | 39 bytes |
| 04 | [和暦](problems/04-wareki/README.md) | ★★☆ | 200 bytes |
| 05 | [しりとり審判](problems/05-shiritori/README.md) | ★★☆ | 89 bytes |
| 06 | [数字ヒストグラム](problems/06-digit-histogram/README.md) | ★★☆ | 100 bytes |
| 07 | [鏡文字](problems/07-mirror/README.md) | ★★☆ | 110 bytes |
| 08 | [あみだくじ](problems/08-amidakuji/README.md) | ★★☆ | 85 bytes |
| 09 | [Ruby インデント整形](problems/09-ruby-indent/README.md) | ★★★ | 201 bytes |
| 10 | [罫線化](problems/10-box-drawing/README.md) | ★★★ | 251 bytes |

「パー」は `solutions/` にある参考解のバイト数です。まずはこれを下回ることを目指してください。

## ルール

- Ruby 3.3 以上で動くこと。
- 入力は標準入力から読み、答えは標準出力に書くこと。入出力の文字コードは UTF-8 です。
- 外部コマンドの実行（`` ` ``、`system`、`exec`、`IO.popen` など）とネットワークアクセスは禁止。
- gem の `require` は禁止（標準ライブラリはOK。ただし `require` 文もバイト数に含みます）。
- スコアは解答ファイルのバイト数です（末尾の改行1つは数えません）。少ないほど良い。全角文字は3バイトです。
- 出力の比較では、各行末の空白と出力末尾の改行は無視します。
- 1ケースあたりの制限時間は5秒です。

## 採点

```sh
ruby judge.rb 01 my_answer.rb
```

```
  PASS 01
  PASS 02
  PASS 03

01-tally-marks: 3/3 passed
Score: 77 bytes
```

テストケースは `problems/<問題>/tests/*.in` と `*.out` です。

## 参考解（ネタバレ注意）

`solutions/` に各問題の参考解があります。自分で解いてから見てください。

## 構成

```
.
├── judge.rb               # 採点スクリプト
├── problems/
│   ├── 01-tally-marks/
│   │   ├── README.md      # 問題文
│   │   └── tests/         # テストケース (*.in / *.out)
│   ├── 02-ruler/
│   └── ...
└── solutions/             # 参考解（ネタバレ）
```
