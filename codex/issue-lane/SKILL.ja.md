# issue-lane — 1 issue = 1 lane ライフサイクル規律(Codex 版)

[English](SKILL.md) | **日本語**(参考訳 — 正本は英語版)

> herdr pane fleet の「1 issue = 1 lane」規律。issue の lane 割当時、issue close
> 時、lane 監査時、そして worker として自分の lane 衛生を確認するときに使う。
> tab と pane の両ラベルに issue ID 必須。lane は issue と一緒に死ぬ。モデルは
> 台帳 entry がない限り fleet 標準ギアのまま。

## 不変条件(4つ)

1. **1 issue = 1 lane = 1 writer。** issue ID は**二層とも**に載せる:
   tab ラベル先頭語 = `<ISSUE-ID>`、pane(agent)ラベル =
   `<space>/<ISSUE-ID>[-役割]`。二層の食い違いは**流用 drift**。
   PO 常駐 pane(tab ラベル `po`)は対象外
2. **lane は issue と同じ寿命。** 割当で生まれ、Done/Canceled で teardown。
   次の issue への流用禁止 — 新 lane・新ギア・新履歴・新 worktree で始める
3. **モデルは fleet 標準ギア既定。** lane は Codex でも Claude Code でもよい —
   既定実装者: Codex `gpt-5.6-terra`(medium、ブースト `sol` は effort low)、
   Claude Code **`sonnet`**(ブースト層は `opus` 等)。上位ギアは fleet の
   モデル台帳に open entry がある間だけ正当
4. **lane 台帳ファイルを作らない。** 真実 = live の `herdr pane list` × issue
   tracker の照合。台帳ファイルは第二の drift する正本になる

## あなたが worker lane の場合

- tab/pane ラベルがあなたの issue を名指ししている。**その issue だけをやる。**
  別 issue を頼まれ(たくなっ)たら、拒否して報告 — 次の issue には専用 lane が立つ
- 完了時: terminal receipt を合意済み inbox に**先に**書き、次に自分の
  background terminal を全部停止(`/stop`)、それから park。共有 lock
  (テスト直列化 lock 等)を握った background プロセスを残さない — 漏れた
  holder は fleet 全体を starve させる
- **自分のモデルを自分で切り替えない。** 同じ失敗に繰り返しはまったら報告に
  書く。昇格は supervisor が台帳経由で行う

## あなたが supervisor / PO lane の場合

### 割当(issue → lane)

1. 二重チェック: この issue ID を持つ pane が既にあれば、新設せずそこへ送る
2. fleet の bootstrap 手順で lane を作る。runtime(Codex / Claude Code)を選び、
   モデルを明示(Codex: `gpt-5.6-terra`、Claude Code: `sonnet`)。tab ラベルは
   issue ID で始める
3. kickoff に明記: 「この lane は <ISSUE-ID> 専用。完了時は background terminal
   を停止してから park。他 issue の作業禁止」

### クローズ(issue close → teardown)

**tracker 実測**の Done/Canceled でトリガ — Linear(MCP `get_issue`)、Jira
(CLI/MCP、`PROJ-123` 形式は同じ `ABC-123` パターン)、GitHub Issues
(`gh issue view`)— lane の自己申告では動かさない: background プロセス残存を
検証(共有 lock holder を確認、kill 前に stale 判定)、worktree/branch 削除、
pane を **close**(rename 再利用禁止)、開いている台帳 entry を閉じる。

### 監査 sweep

`pane list` 単独で監査しない — 流用 drift の痕跡は tab 層にしか残らない
(実測: pane ラベルは現行に見え、tab は closed issue を指していた)。
`herdr tab list` × `herdr pane list` を `tab_id` で join し、両ラベルから
issue ID を抽出して三点照合(層 vs 層、両方 vs tracker)。モデルは pane footer
から実測。

| 違反 | 処置 |
|---|---|
| orphan(両層に issue ID なし) | owner に照会。次 sweep まで未回収なら close |
| zombie(issue closed、lane 生存) | 即 teardown → close |
| 二重 writer(同一 issue、2+ pane) | 後発を停止 |
| 無断ブースト | 降格 — Codex pane: `scripts/model-switch.sh`(メニュー実測、fail-closed)、Claude Code pane: `/model` ピッカーを同じ規律で。owner に通知 |
| 流用 drift(層の食い違い / tab が closed issue) | 実作業を特定。park 待ち → teardown。次 issue は新 lane |
| lane の無い In Progress issue | owner に報告(代理で割り当てない)|

報告は最後に1回: workspace / pane / issue / 違反 / 処置 —
または「swept N panes, 0 violations」。

## アンチゴール

- lane 台帳ファイル禁止。closed issue lane の「念のため」温存禁止
- 無断ブースト降格を発見ターンから先送りしない
- モデル切替でメニュー番号を盲打ちしない — 必ず実測メニューから番号を導出
  (`scripts/model-switch.sh` 参照)
