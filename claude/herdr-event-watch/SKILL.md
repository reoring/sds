---
name: herdr-event-watch
description: Switch herdr fleet supervision from fixed-interval patrols to event-driven watching. Emits only lane done/blocked transitions, PR required-check pass/fail finalizations, and durable inbox-artifact arrivals, via the Monitor tool. Use for "watch this event-driven", "tell me when the lane/PR finishes", or when periodic patrol keeps reporting "no change".
---

# herdr-event-watch — event-driven lane/PR watching

**English** | [日本語](SKILL.ja.md)

Canonical procedure for getting notified **the moment something changes**
instead of polling on a fixed interval. Fixed-interval patrol loses twice: a
lane that parks 3 minutes in goes unnoticed for up to the full interval, and
the patrol runs even when nothing happened.

## When to use

- Multiple worker/review lanes are running and you want PARK (done) / blocked
  picked up immediately.
- You are waiting on PR required checks (branch protection) to go green/fail
  before a merge decision.
- Your periodic "worker patrol" cron has degenerated into "no change" reports.

## Usage

Arm one Monitor with **persistent: true** (a single watcher covers lanes and CI):

```
Monitor({
  description: "<what is being watched — e.g. api lanes + inbox + PR #109 CI>",
  persistent: true,
  command: "bash <skill-dir>/scripts/herdr-event-watch.sh \
    --workspace <wsId> --prefix <laneLabelPrefix> \
    --inbox <receiptDir> --inbox-prefix <filePrefix> \
    --repo <owner/repo> --check <requiredCheckName> --pr <n> [--pr <n> ...]"
})
```

Arguments:

| Arg | Required | Meaning |
|---|---|---|
| `--workspace` | ✔ | herdr workspace ID (`herdr workspace list`) |
| `--prefix` | | lane-label prefix filter (e.g. `api/`); default: all labeled panes |
| `--inbox` (repeatable) | | **durable artifact arrival watch (primary)** — the dir receipts/verdicts land in |
| `--inbox-prefix` | | filename prefix filter |
| `--repo` / `--pr` (repeatable) | | PR required-check watch; omit for lanes-only |
| `--check` | | required check name (default `cloud`) |
| `--interval` | | poll seconds (default 10; gh auto-throttled to ~1/min) |
| `--once` | | one pass then exit (smoke test) |

## Events (1 stdout line = 1 notification)

- `INBOX <filename>` — new file arrived. **Durable artifact, never missed
  (primary).** Files existing when the watch starts form the baseline
  (silent) — after re-arming, manually sweep anything that arrived while the
  watcher was down.
- `LANE <label>=done|blocked` — the lane transitioned into that state.
  Sampled, so transients can be missed (see traps) — use as the stall/blocked
  backstop.
- `CI PR#<n> <check> -> pass|fail (head <sha>)` — required check finalized.
  Once per PR×result×head (head is part of the dedup key, so a
  re-finalization on a new head after update-branch is also emitted).
- `WATCH ERROR <msg>` — the watch itself is persistently failing.

## Design rules (read before changing anything)

1. **Never emit working⇄idle flapping.** done/blocked only — noise kills
   event-driven supervision.
2. **Emit CI pass AND fail** (silence ≠ success). A watch that cannot surface
   failure is half-blind.
3. **A transient failure must not kill the loop.** Single gh/herdr errors are
   swallowed; only persistent failure emits WATCH ERROR.
4. **Keep a time-based patrol as backstop.** Events are primary; a cron is the
   insurance for watcher death. Avoid double-handling by making the cron check
   state and exit quickly when nothing changed.

## Operations

- **Changing the PR list** (merged / new PRs): stop the Monitor task, re-arm
  with new arguments — a Monitor's arguments cannot be changed live.
- **Stopping**: find the task ID (TaskList) and stop it (TaskStop).
- After an event: verify the artifact/pane for real, update the tracker, wake
  successors. **A notification means "look", not "believe"** — always read the
  pane/receipt yourself.

## Traps (all measured in production)

- `herdr pane list` may omit labels for panes without a started agent →
  unlabeled panes are invisible to the watch. Always label lanes on creation
  (see the issue-lane skill's two-layer label rule).
- Dozens of PRs on one watcher hits gh rate limits. Watch only PRs currently
  awaiting a decision.
- `sleep` inside the Monitor script is fine; chains of bare `sleep` calls in a
  foreground shell are typically blocked by the harness.
- **`done` is transient — it can vanish between polls** (measured twice). A
  worker's `done` can be consumed by a queued message or a next instruction
  within the poll gap. State sampling misses by principle. The countermeasure
  is built in: use `--inbox` so durable artifacts (terminal receipts /
  verdicts) are the primary signal — files do not disappear. Keep the LANE
  watch as a backstop only, and make workers follow "write the receipt to the
  inbox, then park" ordering.
- **Re-arm gap**: on restart the inbox baseline is re-taken; files that
  arrived while the watcher was down are not emitted. Always sweep manually
  (`ls -t`) right after re-arming.
