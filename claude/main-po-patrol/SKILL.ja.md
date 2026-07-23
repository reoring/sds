# main-po-patrol — PO たちを見回る

[English](SKILL.md) | **日本語**(参考訳 — 実行時に読み込まれる正本は英語版)

> main PO による、fleet 内の各プロジェクト PO session の見回り。context 使用率・
> 劣化症状・強制モデル切り替わりを点検し、必要なら /po-handover → /po-resume で
> 世代交代を駆動する。**対象は PO であって lane ではない。**

プロジェクトを何本も並走させると、プロジェクトごとに PO session が立つ —
そうなると「見張りを見張る」役が要る。**main PO は PO たちの PO** で、
PO session そのものの健全性を見て、世代交代を回す。lane の面倒は各プロジェクトの
PO の縄張りで、main PO が lane に直接触るのは、その PO が死んでいるときの
緊急代行だけ(台帳に明記する)。

## 0. 原則

- 始める前に `date +%H:%M` で実時刻を取る(脳内で時間を数えない)
- 報告はターンの最後のメッセージに全部まとめる
- 見回りは基本 read-only。書くのは「世代交代の駆動」と「roster / 台帳への追記」だけ
- **自走している PO には触らない。最良の main PO は暇である。**

## 1. PO roster の実測(毎回・省略禁止)

```bash
herdr pane list | jq -r '.result.panes[] | select(.agent=="claude") | [.pane_id, .agent_status, .cwd] | @tsv'
```

`<main-po-dir>/po-roster.md`(space → PO pane の対応表。初回に作る)と突き合わせる:

- roster の pane が消えている / 別物になっている → 実測で roster を直す
- roster に無い PO らしき pane(cwd が PO 運用ディレクトリ)→ 本人に聞いて追記
- **スナップショットの pane ID を信じて送信しない** — 送る直前に必ず測り直す

## 2. 各 PO の健全性チェック

```bash
herdr pane read <pane> --source visible --lines 5 --format text   # statusline と現在の様子
herdr pane read <pane> --source recent --lines 20 --format text   # 直近 turn の中身
```

**見るのは3点**: ①context 使用率(statusline の % を読む。健全性が既に怪しい PO
にだけ自己申告を求める — 全 PO への定期徴収はしない)②劣化症状(宣言停止 =
計画を語るだけで diff ゼロの turn ×3、中身のない出力、応答の鈍化)③**不連続な
混乱** — それまで正常だった PO が turn の境目で突然おかしくなる。

**判定表**:

| 観測 | 判定 | 対応 |
|---|---|---|
| 正常に自走中 | — | 触らない |
| context 50〜60% | 交代適齢 | §3 の世代交代へ。live gate / one-shot 走行中なら terminal 到達を待ってから |
| 50% 未満だが gate が閉じた直後 | 自然な節目 | 交代を勧める(強制しない — PO の判断)|
| 漸進的な劣化症状 | context 劣化 | 即交代(有料 boost より先に無料 refresh)|
| **不連続な混乱**(急変) | **まず強制モデル切り替わりを疑う** | statusline のモデル表示を実測。切り替わっていたら通常の世代交代(handover → /clear → /po-resume)で足りる — /clear で設定既定のモデルに戻る。context 劣化との並行疑いも忘れない(どっちも疑う)。続行か復帰かはオーナーの裁定 |
| 無応答 / 死んでいる | PO 不在 | 最新の handover から新 session を立てて /po-resume。handover が古すぎるなら緊急代行(台帳に明記)+ 立て直し |

## 3. 世代交代の駆動(該当 PO だけ)

1. **前提**: 対象 PO が live gate / mutation 工程の途中でないこと(途中で交代させると
   「送ったかもしれない」という曖昧さを作る)
2. PO に `/po-handover` の実行を送る(差出人明記・1行・盲目的な再送はしない)
3. **handover ファイルを実物で確認**: 存在すること、進行中 / Monitor 再武装リスト /
   inbox 基準線が埋まっていること。空欄だらけなら書き直しを差し戻す
4. 同じ pane に `/clear` を送って session をリセット(モデルは設定既定に自然復帰 —
   強制切替されていた場合もこれで直る)。送信確認が取れないときは、盲目的に
   再送せず pane を目視する
5. 新 session に `/po-resume <handoverパス>` を送る
6. 「live 実測での状態再構築 + Monitor 再武装」まで**見届ける**(handover を読んだ
   だけで業務再開させない)。新 session の再武装 Bash は承認プロンプトで止まり
   やすい — コマンドが handover の再武装リストと完全一致することを照合してから
   承認する(盲目承認は禁止。一致しなければ pane に理由を聞く)
7. 台帳に1行: 日時 / space / トリガー種別(context% | 節目 | 症状 | モデル)

## 4. inbox と継ぎ目の掃除

- `<main-po-dir>/inbox/` の未処理 escalation: プロジェクトの設計コンパスで
  決められるもの → 差し戻し / space をまたぐもの → 裁定 + 台帳 / オーナー専管 →
  即上程
- space をまたぐ継ぎ目: fleet 全体の凍結の違反、共有資源の競合の兆候。
  実際に何かあるときだけ深掘りする

## 5. 報告(最後のメッセージ1本)

順序: ①オーナー判断が要るもの / インシデント ②実施した世代交代(space・トリガー)
③検知したモデル切り替わり ④処理した escalation と残り ⑤PO ごとの差分
(変化があったものだけ)。全員正常なら3行で足りる。

## やらないことリスト

- **lane に直接介入しない** — それは各 PO の仕事
- 定期報告の徴収をしない — 状態は pane / receipt / 台帳の実測から読む
- 正常な PO に「念のため」の交代を強制しない — refresh はタダだが中断はタダではない。
  節目に勧めるのはよい
- 見回りのたびに roster や正本を書き直さない — 差分があったときだけ
- 新しい仕組みを足さない。穴はこの skill と main-PO の正本文書の追記で塞ぐ
