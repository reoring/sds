# watch-po — PO の停止・異常のイベント監視

[English](SKILL.md) | **日本語**(参考訳 — 実行時に読み込まれる正本は英語版)

> PO pane 群の「止まった / おかしい」をイベント駆動で main PO に届ける —
> 承認プロンプトでの停止(POPROMPT)、context 閾値の跨ぎ(POCTX)、強制的な
> モデル切り替わり(POMODEL)、pane の消滅(PODEAD)を、常駐 Monitor で検知し、
> 必要なら通知トピックにも push する。main-po-patrol(定期見回り)の間隙を
> 埋める常設センサー。

`main-po-patrol` が「定期の見回り」なら、これは**見回りと見回りの間を埋める
常設センサー**。生まれたきっかけは実事故 — 世代交代したての PO session が2つ、
Monitor 再武装の承認プロンプトで止まり、2回とも main PO より先に人間のオーナーが
気づいた。最初に気づくべきは main PO だ。

## 検知するイベント(すべて dedup 済み — 遷移した瞬間だけ)

| イベント | 意味 | main PO の初動 |
|---|---|---|
| `POPROMPT <label> <pane>` | 承認 / 入力待ちで停止 | pane を目視 → コマンドを handover / 正本と照合してから承認 or 拒否(盲目承認しない)|
| `POCTX <label> <pane> <pct>%` | context が閾値(既定 60%)を跨いだ | live gate の走行有無を確認 → 世代交代(main-po-patrol §3)|
| `POMODEL <label> <pane> <from>-><to>` | statusline のモデルが変わった | プラットフォームがモデルを黙って切り替えることは実測済み。続行か復帰かはオーナーが決める |
| `PODEAD <label> <pane>` | pane が消えた | 最新の handover から立て直し |
| `POBACK <label> <pane>` | PROMPT / DEAD から復帰 | 記録のみ |
| `WATCH ERROR <msg>` | 監視そのものの失敗 | herdr の状態確認 |

## 武装のしかた(main PO session で)

1. roster から PO pane を読む(**武装する直前に `herdr pane list` で測り直す** —
   pane ID はズレる。roster と食い違ったら roster を先に直す)
2. 常駐 Monitor で起動:

```bash
bash <skill-dir>/scripts/watch-po.sh \
  --pane <paneId>=<space>/po [--pane ...] \
  --ctx-threshold 60 --interval 30 [--ntfy <topic>]
```

ラベルは必ず **`<space>/po` 形式** — 人間のオーナーが読むのはラベルで、pane ID
ではない(pane ID は括弧内の補助)。herdr の pane 自体にも同じラベルを付けておく
(`herdr pane rename <pane> '<space>/po'`)。

3. `--ntfy <topic>` を付けると各イベントを `ntfy.sh/<topic>` にも push
   (イベントは dedup 済みなので通知は少ない)
4. 武装したら台帳に1行 — そして**自分の handover の Monitor 再武装リストに必ず
   書く**(Monitor は session と一緒に死ぬ)

## イベントを受けたときの規律

- **POPROMPT 最優先** — その PO の時間は止まっている。ただし承認は pane を目視し、
  コマンドを handover / 正本と照合してから
- POCTX は「即交代」ではない — live gate / one-shot の走行中なら terminal 到達を待つ
- POMODEL: 勝手にモデルを戻さない — 負荷を見てオーナーが決める(軽負荷なら
  そのまま続行もある)
- 対応したら台帳に1行。POBACK は記録だけで介入しない

## 制約(知っておく)

- 検知は**見えている画面**の grep — 一瞬でスクロールに流れたプロンプトは拾えない
  (実用上、承認プロンプトは応答まで画面に居座るので取りこぼさない)
- statusline にモデル名と `[ctx:NN%]` が表示されている前提 — 形式が違うなら
  スクリプトの正規表現を自分の statusline に合わせて直す
- POMODEL の基準は武装後の初回観測 — 武装より**前**に起きた切り替わりは見えない。
  そこは見回り(main-po-patrol §2)のモデル点検が補完する
- pane を作り直す方式の世代交代をしたら watch の張り直しが必要。同 pane の
  `/clear` 方式なら不要(pane ID が変わらない)

## やらないことリスト

- これで見回りを廃止しない — watch に見えるのは「止まった」だけ。「動いているのに
  進んでいない」(宣言停止・中身のない出力)は、見回りで実際に読まないと捕まらない
- worker lane を対象に足さない — lane は各 PO の herdr-event-watch の縄張り
