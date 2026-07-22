# issue-lane — 1 issue = 1 lane ライフサイクル規律

[English](SKILL.md) | **日本語**(参考訳 — 正本は英語版)

> herdr 管理のエージェント fleet に対する「1 issue = 1 lane」規律。issue を
> worker lane に割り当てるとき、issue が close したとき(「lane も閉じて」)、
> lane 監査(「lane 監査」「棚卸し」)のときに使う。tab と pane の**両方**に
> issue-ID ラベルを付けて lane を作り、issue close で teardown し、
> tab ラベル × pane ラベル × tracker 状態の三点照合で drift を監査する。

lane の生成・teardown・モデル昇降格には fleet ごとの正本手順(bootstrap /
teardown / model-gear 規約)がある。本スキルはそれらを **issue のライフサイクル
に縛る規律**と **drift 検出**を担う。

## なぜ

マルチ PO のエージェント fleet で実測した失敗モード: ブースト済みの高価な
モデルのまま lane が別 issue の作業に流用されてコストが漏れた。closed issue の
lane が残存して fleet が読めなくなった。pane ラベルだけ付け替えて lane が
無言で issue 跨ぎ再利用され、古い真実は tab にだけ残った。lane を issue に
1:1 で縛れば `pane list` = 「実際に進行中のもの」になり、管理が実測に戻る。

## 不変条件(4つ)

1. **1 issue = 1 lane = 1 writer。** issue ID は**二層とも**に載せる:
   - **tab ラベル**: 先頭語 = `<ISSUE-ID>`(例 `PROJ-123 api-freeze`)
   - **pane(agent)ラベル**: `<space>/<ISSUE-ID>[-役割]`(例 `api/PROJ-123`)

   二層が指す issue が食い違ったら**流用 drift**(pane ラベルだけ付け替えて
   別作業をしている状態)。PO 常駐 pane(tab ラベル `po`)は対象外
2. **lane は issue と同じ寿命。** 割当で生まれ、Done/Canceled で teardown。
   「次の issue に流用」は禁止 — 次の issue には新しい lane(モデル・履歴・
   worktree を初期状態から)
3. **モデルは fleet 標準ギア既定。** lane は Codex でも Claude Code でもよい —
   既定実装者: Codex `gpt-5.6-terra`(medium、ブーストギア `sol` は effort low)、
   Claude Code **`sonnet`**(ブースト層は `opus` 等)。上位ギアで走ってよいのは
   モデル台帳に open entry がある間だけ。台帳にない上位ギアは見つけ次第降格
4. **lane 台帳ファイルを作らない。** SOT は live の `herdr pane list` × issue
   tracker の突き合わせ。台帳ファイルは第二の drift する正本になる

## 割当(issue → lane)

1. **二重割当チェック**: 対象 workspace の `herdr pane list` に同じ issue ID の
   pane があれば新設せず、その pane に送る
2. **新設**は fleet の lane-bootstrap 手順で。lane ごとに runtime(Codex /
   Claude Code)を選び、モデルを**明示**する(既定に頼らない。Codex:
   `gpt-5.6-terra`、Claude Code: `sonnet`)。tab ラベルは issue ID で始める
3. **kickoff メッセージ**(pane ID 宛)に必ず含める:

   > この lane は <ISSUE-ID> 専用。完了時は background terminal をすべて停止
   > してから park して報告すること。他 issue の作業は行わない。

## クローズ(issue close → lane teardown)

トリガ: PR merge + issue Done/Canceled を **tracker で実測** — lane の自己申告
では動かさない。どの tracker でも動く: Linear(MCP `get_issue`)、Jira
(CLI/MCP、`PROJ-123` 形式の key は同じ `ABC-123` パターン)、GitHub Issues
(`gh issue view`)。

1. tracker で issue 状態を確認
2. 安全に teardown: background プロセス残存を検証(特に共有 lock の holder)、
   kill 前に stale 判定、その後 worktree/branch 削除
3. **pane を close**(rename 再利用しない — それが label/issue drift の始まり)
4. モデル台帳にブースト entry があれば閉じる

## 監査 sweep(「lane 監査」)

**`pane list` 単独で監査しない。** 実測した教訓: pane ラベルは現行に見えたのに
tab ラベルが closed issue を指していた — issue 跨ぎ流用の痕跡は tab 層にしか
残らなかった。

1. `herdr workspace list` → workspace ごとに `herdr tab list` と
   `herdr pane list` の**両方**を取り、`tab_id` で join
2. tab ラベルと pane ラベルから issue ID を抽出し、(a) 二層同士 (b) tracker
   状態、の両方と照合(三点照合)。`ABC-123` パターンは Linear と Jira 共通、
   GitHub Issues は `#<n>` / `owner/repo#<n>`
3. モデルは pane footer から実測:
   ```bash
   herdr pane read <pane> --source visible --lines 3 --format text | tail -1
   ```
4. 違反と処置:

| 違反 | 検出 | 処置 |
|---|---|---|
| orphan lane | どちらの層にも issue ID なし | owner PO に照会。次 sweep まで所属不明なら close |
| zombie lane | issue Done/Canceled なのに pane 生存 | 即 teardown → close |
| 二重 writer | 同一 issue ID が 2+ pane | 後発を停止、先発に集約 |
| 無断ブースト | footer が上位ギア、台帳に open entry なし | 降格 — Codex pane: `scripts/model-switch.sh`(fail-closed、番号盲打ち禁止)、Claude Code pane: `/model` ピッカーを同じ実測規律で。owner PO に通知 |
| 流用 drift | 二層が食い違う / tab が closed issue | 実作業を特定。working なら park 待ち → teardown。次 issue は新 lane |
| 割当漏れ | In Progress issue に lane なし | owner PO に報告(代理で lane を立てない)|

5. 報告は最終メッセージ1本: workspace / pane / issue / 違反 / 処置。
   違反 0 なら「swept N panes, 0 violations」と件数付きで

## アンチゴール

- lane 台帳ファイルを作らない(live 実測 + tracker が SOT)
- closed issue の lane を「まだ使うかも」で温存しない
- 無断ブーストの降格を発見ターンから先送りしない
- owner PO の割当判断を代行しない(sweep は検出と機械的処置のみ)
