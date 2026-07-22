---
name: herdr-event-watch
description: Event-driven watching of herdr lanes, durable inbox artifacts, and PR required checks, instead of fixed-interval polling. Use when supervising worker lanes ("tell me when X finishes"), waiting on PR checks before a merge decision, or when periodic patrol keeps reporting "no change". Runs scripts/herdr-event-watch.sh in a background terminal and reacts to emitted event lines.
---

# herdr-event-watch — event-driven lane/PR watching

**English** | [日本語](SKILL.ja.md)

Get notified the moment something changes instead of polling on a schedule.
Fixed-interval patrol loses twice: a lane that parks 3 minutes in goes
unnoticed for up to the full interval, and the patrol burns turns even when
nothing happened.

## Usage (Codex runtime: background terminal)

Codex has no persistent monitor tool — run the watcher in a **background
terminal** and check its output when you come back to the foreground:

```bash
# start (background terminal)
bash <skill-dir>/scripts/herdr-event-watch.sh \
  --workspace <wsId> --prefix <laneLabelPrefix> \
  --inbox <receiptDir> --inbox-prefix <filePrefix> \
  --repo <owner/repo> --check <requiredCheckName> --pr <n> [--pr <n> ...] \
  | tee /tmp/herdr-events.$$.log
```

- Each stdout line is one event; `tee` keeps a durable log so events are not
  lost while you work.
- For a one-shot state check (no background terminal), add `--once`.
- Stop the watcher with `/stop` on the background terminal **before you park**
  — a leaked watcher process outlives your turn.

## Arguments

| Arg | Required | Meaning |
|---|---|---|
| `--workspace` | ✔ | herdr workspace ID (`herdr workspace list`) |
| `--prefix` | | lane-label prefix filter (default: all labeled panes) |
| `--inbox` (repeatable) | | **durable artifact arrival watch (primary)** — dir where receipts/verdicts land |
| `--inbox-prefix` | | filename prefix filter |
| `--repo` / `--pr` (repeatable) | | PR required-check watch |
| `--check` | | required check name (default `cloud`) |
| `--interval` | | poll seconds (default 10; gh throttled to ~1/min) |
| `--once` | | one pass then exit |

## Events

- `INBOX <filename>` — durable artifact arrived; never missed (primary).
  Pre-existing files are the silent baseline — after (re)starting the watcher,
  sweep older arrivals manually (`ls -t`).
- `LANE <label>=done|blocked` — sampled transition; transients can be missed.
  Backstop for stall/blocked detection.
- `CI PR#<n> <check> -> pass|fail (head <sha>)` — once per PR×result×head.
- `WATCH ERROR <msg>` — the watch itself is persistently failing.

## Design rules

1. No working⇄idle flapping — done/blocked only.
2. Emit CI pass AND fail (silence ≠ success).
3. Transient gh/herdr errors never kill the loop; only persistent failure
   emits WATCH ERROR.
4. Keep a coarse time-based patrol as a backstop for watcher death.

## Traps (measured)

- Unlabeled panes are invisible — always label lanes at creation (issue-lane
  two-layer rule).
- Too many PRs on one watcher hits gh rate limits — watch only PRs awaiting a
  decision.
- **`done` is transient**: a worker's done can be consumed within the poll
  gap. Durable inbox artifacts are the primary signal; make workers write the
  receipt **before** parking.
- A notification means "look", not "believe" — read the pane/receipt yourself
  before acting on it.
