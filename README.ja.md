# sds — Software Development Skills

[English](README.md) | **日本語**

規律ある fleet 型ソフトウェア開発のための、ランタイム可搬なエージェントスキル集。
実際のマルチエージェント本番ワークフロー — supervisor(PO)セッションが計画を立て、
tracker に issue を起票し、実装を worker lane に dispatch する — から汎用化した:

> **dev-flow** で計画 → **issue-lane** で各 issue を 1 lane に割当 →
> **herdr-event-watch** で event-driven に監督

## スキル

| スキル | 強制する規律 |
|---|---|
| [dev-flow](claude/dev-flow/SKILL.md) | 段階フロー: 構想 → read-only scout → 設計 → PoC → 確証 → 実装 → 手動 Live 反映 → 観察 → 確定。工程ごとの receipt、fail-closed な gate、差し戻し表、circuit breaker |
| [issue-lane](claude/issue-lane/SKILL.md) | 1 issue = 1 lane のライフサイクル: tab と pane の両方に issue ID ラベル、issue close で teardown、台帳制のモデルブースト、三点照合の drift 監査(tab × pane × tracker) |
| [herdr-event-watch](claude/herdr-event-watch/SKILL.md) | event-driven な fleet 監督: 耐久 inbox artifact(primary)、lane done/blocked 遷移(backstop)、PR required check の確定 — 固定間隔ポーリングの代替 |

worker lane は **Codex / Claude Code のどちらでもよい** — 既定実装者は
Codex `gpt-5.6-terra`(medium)、Claude Code `sonnet`。上位ギア(Codex `sol`、
Claude Code `opus`)は台帳制の一時ブーストのみ。issue tracker は
**Linear・Jira**(どちらも `ABC-123` 形式の key)、GitHub Issues に対応。

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

## ライセンス

MIT
