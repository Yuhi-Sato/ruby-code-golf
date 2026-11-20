# AB02. The bombe

出典: Anybatross YAPC::Hiroshima 2024 Hole 2（[元の問題](https://perlbatross.kayac.com/contest/2024hiroshima/challenge/2)）

## 問題

英小文字の文章を、シーザー暗号（アルファベットを一定の数だけずらす暗号。`z` の次は `a` に戻る）で暗号化したものが与えられます。
ずらす数は行ごとに違い、どの行も元の文章の最初の単語は `yapc` です。各行を復号して出力してください。

例えば1つずらすと `a→b`、`z→a` になります。

## 入力

- 1行以上。各行は英小文字の単語を空白1つで区切ったもので、最初の単語は暗号化された `yapc` です。
- ずらす数は 0 以上 25 以下です。

## 出力

復号した文章を1行ずつ出力します。空白はそのままです。

## 入出力例

入力:

```
bdsf jroi lv ixq
xzob
```

出力:

```
yapc golf is fun
yapc
```
