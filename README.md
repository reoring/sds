# sds — Software Development Skills

**English** | [日本語](README.ja.md)

Runtime-portable agent skills for disciplined, fleet-based software
development. Generalized from a real multi-agent production workflow where a
supervisor (PO) session plans work, files tracker issues, and dispatches
implementation to worker lanes:

> plan with **dev-flow** → assign each issue to exactly one lane with
> **issue-lane** → supervise event-driven with **herdr-event-watch**.

## Why — the problem and the solution

**Problem 1: putting a frontier model on everything is expensive.** A single
strong session that plans, implements, and reviews burns top-tier tokens
mostly on mechanical work — and implementation is the bulk of the tokens.
Worse, without structure the strong model quietly stays on for work that a
cheaper model does just as well (we measured exactly this drift in
production: boosted lanes carried an expensive model into unrelated issues).

**Problem 2: the AI tooling landscape is drowning in new platforms.** Every
week brings another orchestration framework to adopt, learn, and depend on.
But supervising an agent fleet does not require any of them. Give your agents
a loop and a goal, and existing simple tools — a pane multiplexer, the issue
tracker you already use, `gh`, a few small single-purpose shell scripts —
compose into the same capability. This repo is deliberately Unix-philosophy:
**no new platform, no runtime dependency** — just markdown skill files and
small scripts that glue together tools you already run.

**Solution: separate judgment from execution, using nothing but what you
already have.**

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
| [po-handover](claude/po-handover/SKILL.md) / [po-resume](claude/po-resume/SKILL.md) | PO session rotation (Claude Code only — POs run on Claude Code in this topology). Rotate at 50-60% context: the handover file is a map (in-flight deltas + pointers), the resuming session re-measures everything live, re-arms watchers, and loads the standard toolkit before working. |
| [main-po-patrol](claude/main-po-patrol/SKILL.md) / [watch-po](claude/watch-po/SKILL.md) | The third tier for multi-project fleets: a **main PO** (a PO of POs) patrols each project PO's health — context usage, degradation, forced model switches — and drives rotations; watch-po is its standing event sensor (approval-prompt stalls, context thresholds, model switches, dead panes). Claude Code only. |

Worker lanes may be **Codex or Claude Code agents** — default implementers:
Codex `gpt-5.6-terra` (medium), Claude Code `sonnet`; higher tiers (Codex
`sol`, Claude Code `opus`) are ledger-controlled boosts only.

## Issue tracking — works with Linear and Jira

The whole issue lifecycle runs on your existing tracker — **Linear or Jira**
work out of the box (GitHub Issues too):

- The PO files and updates issues in the tracker (Linear via MCP, Jira via
  CLI/MCP, GitHub via `gh`).
- Lane labels carry the tracker's issue key; Linear and Jira share the same
  `ABC-123` key pattern, so the two-layer label rule and the audit's
  extraction logic are identical for both.
- Lifecycle triggers are **tracker-measured**: a lane is torn down when the
  tracker says Done/Canceled — never on the lane's self-report.

## The workflow, end to end

How the three skills compose into one delivery loop (this is the workflow the
repo was distilled from — an MVP taken from planning to a live deployment):

1. **Bootstrap.** Create the `<project>` PO space (Claude Code on Opus 4.8 /
   Fable 5, tab `po`) and the `<project>-impl` worker space.
2. **Plan — dev-flow stages 0–2.** The PO writes the concept memo, dispatches
   a read-only scout lane, then designs against the scout receipt and routes
   an independent review. No design without ground truth.
3. **File issues.** The PO breaks the reviewed design into tracker issues
   (Linear / Jira) — each one lane-sized, with acceptance criteria and the
   receipt it must produce, wired with blocking dependencies.
4. **Assign — issue-lane.** For every unblocked issue, spawn one lane in
   `<project>-impl` (tab = issue key, pane = `<project>/<KEY>`, model =
   `sonnet` / `terra` medium) and send the kickoff with the dedication clause.
5. **Supervise — herdr-event-watch.** Arm one watcher over lanes + receipt
   inbox + PR checks. The PO reacts to events instead of polling: INBOX →
   verify the receipt for real; CI pass → merge decision; LANE blocked →
   intervene. Stuck lane? Boost it via the model ledger, demote on
   breakthrough.
6. **Close the loop.** Tracker says Done → tear the lane down (issue-lane);
   file follow-up issues as reviews surface them.
7. **Ship — dev-flow stages 4–8.** Certify the full chain in isolation, apply
   to live manually through the human gate, observe (readback + soak), then
   confirm and feed the lessons back into the flow doc.

The PO never implements; workers never touch live. Every hand-off is a
receipt, every state change is measured, and the expensive model only shows up
where judgment happens.

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
  dispatches, verifies receipts, and adjudicates. PO sessions are disposable
  too: rotate at ~50-60% context via **po-handover → po-resume**, before
  judgment degrades.
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
- **Running several projects at once?** Add a third tier: one **main PO**
  session (also Claude Code, frontier model) that supervises the project POs
  themselves — health patrols via main-po-patrol, a standing watch-po sensor,
  and rotation driving. Its subjects are POs, never lanes.

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

**Claude Code — as a plugin (recommended):**

```
/plugin marketplace add reoring/sds
/plugin install sds@sds
```

Skills load namespaced (`/sds:dev-flow`, `/sds:issue-lane`, …) and update via
`/plugin marketplace update sds`.

**Both runtimes — one-shot npx installer:**

```bash
npx @reoring/sds            # install both (claude + codex)
npx @reoring/sds --codex    # Codex CLI skills only -> ~/.codex/skills/
npx @reoring/sds --claude   # Claude Code skills only -> ~/.claude/skills/
```

Fail-closed: existing skill directories are never overwritten without
`--force`. `--dry-run` previews.

**Manual fallback:**

```bash
cp -r claude/* ~/.claude/skills/
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

## Used in production

These skills are not a thought experiment — they are the actual workflow used
to develop **AppThrust** ([appthrust.com](https://appthrust.com/) ·
[github.com/appthrust](https://github.com/appthrust/)), running multi-agent
fleets daily across planning, implementation, review, and live releases.

Measured effect: adopting this PO/worker split with ledger-controlled boosts
cut our token spend from **about $12,000/day to about $900/day — a ~92%
reduction** — with frontier-model quality retained at the decision points.

## License

MIT
