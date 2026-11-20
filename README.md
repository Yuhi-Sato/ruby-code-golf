# Ruby Code Golf

Ruby で解く、コードゴルフ（できるだけ短いコードで解く競技）の問題集です。

## 問題

| # | 問題 | 難易度 | パー |
| --- | --- | --- | --- |
| 01 | [Look-and-Say（読み上げ数列）](problems/01-look-and-say/README.md) | ★☆☆ | 64 bytes |
| 02 | [ナンバーダイヤモンド](problems/02-number-diamond/README.md) | ★★☆ | 69 bytes |
| 03 | [ローマ数字](problems/03-roman-numerals/README.md) | ★★★ | 145 bytes |

「パー」は `solutions/` にある参考解のバイト数です。まずはこれを下回ることを目指してください。

## ルール

- Ruby 3.3 以上で動くこと。
- 入力は標準入力から読み、答えは標準出力に書くこと。
- gem の `require` は禁止（標準ライブラリはOK。ただし `require` 文もバイト数に含みます）。
- スコアは解答ファイルのバイト数です（末尾の改行1つは数えません）。少ないほど良い。
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
  PASS 04

01-look-and-say: 4/4 passed
Score: 64 bytes
```

テストケースは `problems/<問題>/tests/*.in` と `*.out` です。

## 参考解（ネタバレ注意）

`solutions/` に各問題の参考解があります。自分で解いてから見てください。

## 構成

```
.
├── judge.rb               # 採点スクリプト
├── problems/
│   ├── 01-look-and-say/
│   │   ├── README.md      # 問題文
│   │   └── tests/         # テストケース (*.in / *.out)
│   ├── 02-number-diamond/
│   └── 03-roman-numerals/
└── solutions/             # 参考解（ネタバレ）
```
