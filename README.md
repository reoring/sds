# sds — Software Development Skills

**English** | [日本語](README.ja.md)

Runtime-portable agent skills for disciplined, fleet-based software
development. Generalized from a real multi-agent production workflow where a
supervisor (PO) session plans work, files tracker issues, and dispatches
implementation to worker lanes:

> plan with **dev-flow** → assign each issue to exactly one lane with
> **issue-lane** → supervise event-driven with **herdr-event-watch**.

## Why — the problem and the solution

**Problem: putting a frontier model on everything is expensive.** A single
strong session that plans, implements, and reviews burns top-tier tokens
mostly on mechanical work — and implementation is the bulk of the tokens.
Worse, without structure the strong model quietly stays on for work that a
cheaper model does just as well (we measured exactly this drift in
production: boosted lanes carried an expensive model into unrelated issues).

**Solution: separate judgment from execution.**

| Role | Model tier | Token share | What it does |
|---|---|---|---|
| PO (1 per project) | frontier (Opus 4.8 / Fable 5) | small | plan, design gates, file issues, verify receipts, adjudicate |
| Workers (1 per issue) | standard (`sonnet` / `gpt-5.6-terra` medium) | bulk | execute well-specified issues, produce receipts |
| Boost / spot review | frontier, **temporary** | exceptional | stuck-breakthrough, blocking reviews — ledger-controlled |

The judgment-heavy loop is a small fraction of total tokens, so the frontier
model is paid for only where it changes outcomes. The token bulk —
implementation of already-specified work — runs on commodity gear. And because
every boost requires an open ledger entry and every lane dies with its issue
(issue-lane), expensive-model drift is structurally impossible instead of
merely discouraged: frontier quality at the decision points, commodity cost
for the volume.

## Skills

| Skill | What it enforces |
|---|---|
| [dev-flow](claude/dev-flow/SKILL.md) | Staged flow: concept → read-only scout → design → PoC → certify → implement → manual live apply → observe → confirm. Per-stage receipts, fail-closed gates, rollback table, circuit breaker. |
| [issue-lane](claude/issue-lane/SKILL.md) | 1 issue = 1 lane lifecycle: issue-ID labels on both tab and pane, teardown on issue close, ledger-controlled model boosts, three-way drift audit (tab × pane × tracker). |
| [herdr-event-watch](claude/herdr-event-watch/SKILL.md) | Event-driven fleet supervision: durable inbox artifacts (primary), lane done/blocked transitions (backstop), PR required-check finalizations — instead of fixed-interval polling. |

Worker lanes may be **Codex or Claude Code agents** — default implementers:
Codex `gpt-5.6-terra` (medium), Claude Code `sonnet`; higher tiers (Codex
`sol`, Claude Code `opus`) are ledger-controlled boosts only. Issue trackers:
**Linear, Jira** (both use `ABC-123`-style keys), and GitHub Issues.

## Fleet topology (herdr lane operation)

The skills assume this herdr workspace layout, one pair of spaces per project:

```
herdr
├── <project>              PO space
│   └── tab "po"           the project's PO session — Claude Code on
│                          Opus 4.8 or Fable 5 (recommended)
└── <project>-impl         worker space (1 issue = 1 tab = 1 lane)
    ├── tab "PROJ-123 api-freeze"   pane "<project>/PROJ-123"        implementer
    ├── tab "PROJ-124 rate-limit"   pane "<project>/PROJ-124"        implementer
    └── tab "PROJ-124-review"       pane "<project>/PROJ-124-review" reviewer (read-only)
```

- **One PO per project.** The PO session plans with dev-flow, files tracker
  issues, assigns lanes with issue-lane, and supervises with
  herdr-event-watch. It lives in the project's own space under a tab labeled
  `po` (exempt from the issue-ID label rule) and never implements — it
  dispatches, verifies receipts, and adjudicates.
- **One `<project>-impl` space for workers.** Every issue gets its own tab;
  the tab label starts with the issue ID, and the agent pane label is
  `<project>/<ISSUE-ID>[-role]` (the two-layer rule that makes reuse drift
  detectable). Lanes are created at assignment and torn down when the issue
  closes.
- **Implementers** run on the fleet standard gear (Claude Code `sonnet` or
  Codex `gpt-5.6-terra` medium); an optional read-only reviewer lane per issue
  uses a `-review` suffix. Boosts are ledger-controlled and temporary.
- Keep `pane list` readable as the live "what is in progress" view — that is
  the whole point of the topology.

Each skill exists in two runtime variants:

- `claude/` — for Claude Code (`~/.claude/skills/`); uses the Monitor tool for
  persistent watching and MCP/CLI trackers.
- `codex/` — for Codex CLI (`~/.codex/skills/`); adds worker-lane
  self-discipline sections and uses background terminals instead of Monitor.

Bundled scripts (battle-tested, fail-closed):

- `herdr-event-watch/scripts/herdr-event-watch.sh` — the event emitter
  (INBOX / LANE / CI / WATCH ERROR lines).
- `issue-lane/scripts/model-switch.sh` — safe model switching for codex TUI
  panes: reads the actual picker menu, derives the option number from an exact
  name match, verifies the footer afterwards. Born from a real misfire where a
  blind menu-number press selected a legacy model.

## Install

```bash
# Claude Code
cp -r claude/* ~/.claude/skills/

# Codex CLI
cp -r codex/* ~/.codex/skills/
```

Skills are self-contained; `herdr` (pane fleet CLI), `gh`, `jq`, and `python3`
are expected on PATH where the scripts are used.

## Design notes

- **Receipts over claims.** Every stage/lane action produces a durable
  artifact (path + SHA). "Verbally done" is not done.
- **Fail-closed everywhere.** Missing menu entry, missing receipt, footer
  mismatch, unreachable pane — abort and report; never guess, never claim
  unverified success.
- **Live measurement is the source of truth.** No registry files that can
  drift; audits join live pane/tab state with the issue tracker.
- **Events primary, polling as backstop.** Durable artifacts cannot be missed;
  sampled states can — the design uses both accordingly.

## License

MIT
