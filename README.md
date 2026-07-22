# sds — Software Development Skills

Runtime-portable agent skills for disciplined, fleet-based software
development. Generalized from a real multi-agent production workflow where a
supervisor (PO) session plans work, files tracker issues, and dispatches
implementation to worker lanes:

> plan with **dev-flow** → assign each issue to exactly one lane with
> **issue-lane** → supervise event-driven with **herdr-event-watch**.

## Skills

| Skill | What it enforces |
|---|---|
| [dev-flow](claude/dev-flow/SKILL.md) | Staged flow: concept → read-only scout → design → PoC → certify → implement → manual live apply → observe → confirm. Per-stage receipts, fail-closed gates, rollback table, circuit breaker. |
| [issue-lane](claude/issue-lane/SKILL.md) | 1 issue = 1 lane lifecycle: issue-ID labels on both tab and pane, teardown on issue close, ledger-controlled model boosts, three-way drift audit (tab × pane × tracker). |
| [herdr-event-watch](claude/herdr-event-watch/SKILL.md) | Event-driven fleet supervision: durable inbox artifacts (primary), lane done/blocked transitions (backstop), PR required-check finalizations — instead of fixed-interval polling. |

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
