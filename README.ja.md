# sds — Software Development Skills

[English](README.md) | **日本語**

規律ある fleet 型ソフトウェア開発のための、ランタイム可搬なエージェントスキル集。
実際のマルチエージェント本番ワークフロー — supervisor(PO)セッションが計画を立て、
tracker に issue を起票し、実装を worker lane に dispatch する — から汎用化した:

> **dev-flow** で計画 → **issue-lane** で各 issue を 1 lane に割当 →
> **herdr-event-watch** で event-driven に監督

## Why — 課題感とソリューション

**課題: 全部を最上位モデルにやらせるとコストが高い。** 計画も実装もレビューも
1つの強いセッションでやると、トークンの大半を占める機械的な作業(実装)にまで
最上位モデルの単価を払うことになる。しかも構造がないと、安いモデルで十分な作業に
強いモデルが居座り続ける — 実際に本番で、ブースト済み lane が高価なモデルのまま
別 issue に流用される drift を実測した。

**ソリューション: 判断と実行を分離する。**

| 役割 | モデル階層 | トークン比率 | やること |
|---|---|---|---|
| PO(プロジェクトに1つ) | frontier(Opus 4.8 / Fable 5) | 小 | 計画、gate 設計、issue 起票、receipt 検証、裁定 |
| worker(issue に1つ) | 標準(`sonnet` / `gpt-5.6-terra` medium) | 大半 | 仕様化済み issue の実行、receipt 生成 |
| ブースト / スポットレビュー | frontier、**一時的** | 例外 | はまり突破・blocking レビュー — 台帳制 |

判断の重いループはトークン全体のごく一部だから、frontier モデルには「結果を
左右する場所」でだけ課金する。トークンの大半 — 仕様化済み作業の実装 — は
標準ギアで回る。さらに、すべてのブーストに台帳の open entry を要求し、
lane は issue と一緒に死ぬ(issue-lane)から、高価なモデルの居座り drift は
「注意する」ではなく**構造的に不可能**になる: 判断点は frontier 品質、
物量は標準コスト。

## スキル

| スキル | 強制する規律 |
|---|---|
| [dev-flow](claude/dev-flow/SKILL.md) | 段階フロー: 構想 → read-only scout → 設計 → PoC → 確証 → 実装 → 手動 Live 反映 → 観察 → 確定。工程ごとの receipt、fail-closed な gate、差し戻し表、circuit breaker |
| [issue-lane](claude/issue-lane/SKILL.md) | 1 issue = 1 lane のライフサイクル: tab と pane の両方に issue ID ラベル、issue close で teardown、台帳制のモデルブースト、三点照合の drift 監査(tab × pane × tracker) |
| [herdr-event-watch](claude/herdr-event-watch/SKILL.md) | event-driven な fleet 監督: 耐久 inbox artifact(primary)、lane done/blocked 遷移(backstop)、PR required check の確定 — 固定間隔ポーリングの代替 |

worker lane は **Codex / Claude Code のどちらでもよい** — 既定実装者は
Codex `gpt-5.6-terra`(medium)、Claude Code `sonnet`。上位ギア(Codex `sol`、
Claude Code `opus`)は台帳制の一時ブーストのみ。

## Issue 運用 — Linear でも Jira でも使える

issue のライフサイクル全体は、いま使っている tracker の上でそのまま回る —
**Linear でも Jira でも** そのまま使える(GitHub Issues も可):

- PO は tracker 上で issue を起票・更新する(Linear は MCP、Jira は CLI/MCP、
  GitHub は `gh`)
- lane のラベルには tracker の issue key を刻む。Linear と Jira は同じ
  `ABC-123` 形式だから、二層ラベル規則も監査の抽出ロジックも両者で共通
- ライフサイクルのトリガは **tracker の実測**: lane の teardown は tracker が
  Done/Canceled になったとき — lane の自己申告では動かさない

## sds を使ったワークフロー(end to end)

3つのスキルが1つのデリバリーループとして噛み合う流れ(この repo の元になった
実ワークフロー — MVP を計画から live 稼動まで持っていったもの):

1. **Bootstrap。** `<project>` PO space(Claude Code の Opus 4.8 / Fable 5、
   tab `po`)と `<project>-impl` worker space を作る
2. **計画 — dev-flow 工程 0–2。** PO が構想メモを書き、read-only scout lane を
   dispatch し、scout receipt に bind して設計、独立レビューに回す。
   ground truth なしの設計はしない
3. **issue 起票。** レビュー済み設計を tracker の issue(Linear / Jira)に分解 —
   各 issue は lane 1本サイズで、受入条件と生成すべき receipt を明記し、
   blocking 依存で配線する
4. **割当 — issue-lane。** 依存が解けた issue ごとに `<project>-impl` に lane を
   1本立て(tab = issue key、pane = `<project>/<KEY>`、モデル = `sonnet` /
   `terra` medium)、専任条項つき kickoff を送る
5. **監督 — herdr-event-watch。** lane + receipt inbox + PR check を watcher
   1本で arm。PO はポーリングでなくイベントに反応する: INBOX → receipt を実物
   検証、CI pass → merge 判定、LANE blocked → 介入。はまった lane は台帳経由で
   ブースト、突破したら降格
6. **ループを閉じる。** tracker が Done になったら lane を teardown(issue-lane)。
   レビューで見つかった課題は follow-up issue として起票
7. **出荷 — dev-flow 工程 4–8。** 隔離環境で full chain を確証し、人間 gate 経由で
   手動 live 反映、観察(readback + soak)、確定して教訓をフロー文書に還流

PO は実装せず、worker は live に触らない。すべての受け渡しは receipt で、
すべての状態変化は実測され、高価なモデルは判断が発生する場所にだけ現れる。

## Fleet トポロジ(herdr lane 運用)

スキル群は、プロジェクトごとに次の herdr workspace 構成を前提にする:

```
herdr
├── <project>              PO space
│   └── tab "po"           プロジェクトの PO セッション — Claude Code の
│                          Opus 4.8 または Fable 5 推奨
└── <project>-impl         worker space(1 issue = 1 tab = 1 lane)
    ├── tab "PROJ-123 api-freeze"   pane "<project>/PROJ-123"        実装者
    ├── tab "PROJ-124 rate-limit"   pane "<project>/PROJ-124"        実装者
    └── tab "PROJ-124-review"       pane "<project>/PROJ-124-review" レビュワ(read-only)
```

- **プロジェクトごとに PO を1つ。** PO セッションは dev-flow で計画し、tracker に
  issue を起票し、issue-lane で lane を割り当て、herdr-event-watch で監督する。
  プロジェクト自身の space の `po` ラベルの tab に常駐(issue-ID ラベル規則の対象外)。
  PO は実装しない — dispatch・receipt 検証・裁定に徹する
- **worker は `<project>-impl` space に。** issue ごとに tab を1つ。tab ラベルは
  issue ID で始まり、agent pane ラベルは `<project>/<ISSUE-ID>[-役割]`
  (流用 drift を検出可能にする二層ラベル規則)。lane は割当時に生まれ、
  issue close で teardown される
- **実装者**は fleet 標準ギア(Claude Code `sonnet` または Codex `gpt-5.6-terra`
  medium)。issue ごとに任意で read-only レビュワ lane(`-review` サフィックス)。
  ブーストは台帳制・一時的
- `pane list` がそのまま「いま何が進行中か」のライブビューとして読める状態を保つ —
  それがこのトポロジの目的

## ランタイム別バリアント

各スキルは2つのランタイム向けに存在する:

- `claude/` — Claude Code 用(`~/.claude/skills/`)。持続監視に Monitor ツール、
  tracker には MCP/CLI を使う
- `codex/` — Codex CLI 用(`~/.codex/skills/`)。worker lane の自己規律の章が
  追加され、Monitor の代わりに background terminal を使う

同梱スクリプト(本番実証済み・fail-closed):

- `herdr-event-watch/scripts/herdr-event-watch.sh` — イベント emitter
  (INBOX / LANE / CI / WATCH ERROR の行を出力)
- `issue-lane/scripts/model-switch.sh` — codex TUI pane の安全なモデル切替:
  実際のピッカーメニューを読み、名前の完全一致から選択番号を導出し、切替後に
  footer を検証する。番号の盲打ちで legacy モデルに誤切替した実事故から生まれた

## インストール

```bash
# Claude Code
cp -r claude/* ~/.claude/skills/

# Codex CLI
cp -r codex/* ~/.codex/skills/
```

スキルは自己完結。スクリプトを使う環境では `herdr`(pane fleet CLI)、`gh`、
`jq`、`python3` が PATH にあることを想定する。

## 設計メモ

- **主張より receipt。** 工程・lane の操作は必ず耐久 artifact(パス + SHA)を残す。
  「口頭で done」は done ではない
- **どこでも fail-closed。** メニューに目的が無い、receipt が無い、footer 不一致、
  pane 不達 — すべて中断して報告。推測しない、未検証の成功を主張しない
- **ライブ実測が正本。** drift しうる台帳ファイルを作らない。監査は live の
  pane/tab 状態と issue tracker の突き合わせで行う
- **イベントが primary、ポーリングは backstop。** 耐久 artifact は取りこぼさない。
  サンプリングされる状態は取りこぼす — 設計はその両方を前提に組む

## 実運用実績

このスキル群は机上の実験じゃなく、**AppThrust**
([appthrust.com](https://appthrust.com/) ·
[github.com/appthrust](https://github.com/appthrust/))の実際の開発で
使っているワークフローそのもの。計画・実装・レビュー・live リリースまで、
マルチエージェント fleet で日々回している。

実測効果: この PO/worker 分離 + 台帳制ブーストの導入で、トークン費用を
**約 60% 削減**できた(判断点の frontier モデル品質は維持したまま)。

## ライセンス

MIT
