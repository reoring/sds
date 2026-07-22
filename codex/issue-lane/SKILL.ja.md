# issue-lane — 「1 issue = 1 lane」のライフサイクル規律(Codex 版)

[English](SKILL.md) | **日本語**(参考訳 — 実行時に読み込まれる正本は英語版)

> herdr の pane fleet に「1 issue = 1 lane」を徹底させる。issue を lane に
> 割り当てるとき、issue が閉じたとき、lane の棚卸しのとき、そして worker として
> 自分の lane の衛生状態を確認するときに使う。tab と pane の両方のラベルに
> issue ID を刻む。lane は issue と一緒に死ぬ。モデルは台帳に記載がない限り
> fleet の標準のまま。

## 破ってはいけない4カ条

1. **1 issue = 1 lane = 書き手は1本。** issue ID は**二層とも**に刻む:
   tab ラベルの先頭 = `<ISSUE-ID>`、pane(エージェント)ラベル =
   `<space>/<ISSUE-ID>[-役割]`。二層が食い違っていたら**使い回しのズレ**。
   PO の常駐 pane(tab ラベル `po`)だけは対象外
2. **lane の寿命は issue と同じ。** 割り当てで生まれ、Done/Canceled で畳む。
   次の issue への使い回しは禁止 — 新しい lane を、まっさらなモデル・履歴・
   worktree で立てる
3. **モデルは fleet の標準を使う。** lane は Codex でも Claude Code でもよい。
   標準の実装担当: Codex は `gpt-5.6-terra`(medium。ブースト用 `sol` は
   effort low が基本)、Claude Code は **`sonnet`**(ブースト層は `opus` など)。
   上位モデルが正当なのは、fleet のモデル台帳にこの lane の有効な記載がある間だけ
4. **lane の管理ファイルを作らない。** 正本は、生きている `herdr pane list` と
   issue tracker の突き合わせ。一覧ファイルは実態とズレていく第二の正本になる

## あなたが worker lane なら

- tab / pane のラベルが、あなたの担当 issue を名指ししている。**その issue だけを
  やる。** 別の issue を頼まれたら(やりたくなっても)、断って報告する — 次の
  issue には専用の lane が立つ
- 完了したら: まず terminal receipt を決められた inbox に**先に**書く。次に自分の
  バックグラウンドプロセスを全部止める(`/stop`)。それから待機する。共有ロック
  (テストの直列化ロックなど)を握ったプロセスを残さないこと — 取り残された
  ロック保持者は fleet 全体を止める
- **自分のモデルを自分で切り替えない。** 同じ失敗を繰り返してはまっているなら、
  そう報告に書く。昇格させるかどうかは、監督者が台帳を通して決める

## あなたが監督者 / PO lane なら

### 割り当て(issue → lane)

1. 二重チェック: この issue ID を持つ pane がすでにあれば、新設せずそこへ連絡する
2. fleet の bootstrap 手順で lane を立てる。ランタイム(Codex か Claude Code)を
   選び、モデルを明示する(Codex: `gpt-5.6-terra`、Claude Code: `sonnet`)。
   tab ラベルは issue ID で始める
3. 着手指示に明記する: 「この lane は <ISSUE-ID> 専任。完了したらバックグラウンドの
   プロセスを止めてから待機。ほかの issue には手を出さない」

### 撤収(issue クローズ → lane を畳む)

きっかけは **tracker で実測した** Done/Canceled — Linear(MCP の `get_issue`)、
Jira(CLI / MCP。`PROJ-123` 形式は Linear と同じ `ABC-123` パターン)、
GitHub Issues(`gh issue view`)— lane の自己申告では動かさない。手順:
バックグラウンドプロセスの残存を検証(共有ロックの保持者を確認、止める前に
本当に止めてよいか判定)→ worktree とブランチを削除 → pane は **close**
(名前の付け替え再利用は禁止)→ 台帳に記載が残っていれば閉じる。

### 監査

`pane list` だけを見て監査しない — 使い回しのズレの痕跡は tab の層にしか
残らない(実測: pane ラベルは現行の issue を指して健全に見えたのに、tab は
閉じた issue のままだった)。`herdr tab list` と `herdr pane list` を `tab_id` で
突き合わせ、両方のラベルから issue ID を取り出して三点照合する(層どうし、
そして両方を tracker と)。モデルは pane の画面フッターから実測する。

| 違反 | 対処 |
|---|---|
| 迷子 lane(どちらの層にも issue ID なし)| 持ち主に確認。次の監査まで宙に浮いたままなら閉じる |
| ゾンビ lane(issue は閉、pane は生存)| ただちに撤収 → close |
| 書き手の重複(同じ issue に 2+ pane)| 後から立った方を止める |
| 無断ブースト | 降格 — Codex pane は `scripts/model-switch.sh`(画面を読んでから押す・fail-closed)、Claude Code pane は `/model` ピッカーを同じ流儀で。持ち主に通知 |
| 使い回しのズレ(層の食い違い / tab が閉じた issue)| 実際の作業を特定。待機を待って撤収。次の issue には新しい lane |
| lane のない In Progress issue | 持ち主に報告(勝手に割り当てない)|

報告は最後にまとめて1回: workspace / pane / issue / 違反 / 対処 —
違反ゼロなら「N pane を確認、違反 0」。

## やらないことリスト

- lane の管理ファイルは作らない。閉じた issue の lane を「念のため」残さない
- 無断ブーストの降格を、見つけたターンより先に延ばさない
- モデル切替でメニューの番号を思い込みで押さない — 必ず実際の画面から番号を
  割り出す(`scripts/model-switch.sh` 参照)
