---
name: issue-lane
description: "1 issue = 1 lane" lifecycle discipline for herdr pane fleets. Use when assigning an issue to a lane, when an issue closes, when auditing lanes, or to check your own lane hygiene as a worker. Tab and pane labels must both carry the issue ID; lanes die with their issue; the model stays on the fleet default gear unless a ledger entry authorizes a boost.
---

# issue-lane — 1 issue = 1 lane lifecycle discipline

## Invariants (4)

1. **1 issue = 1 lane = 1 writer.** The issue ID appears on **both label
   layers**: tab label first word = `<ISSUE-ID>`; pane (agent) label =
   `<space>/<ISSUE-ID>[-role]`. Disagreement between the layers is **reuse
   drift**. Resident PO panes (tab label `po`) are exempt.
2. **A lane lives exactly as long as its issue.** Created at assignment, torn
   down at Done/Canceled. Never reuse a lane for the next issue — fresh lane,
   fresh model gear, fresh history, fresh worktree.
3. **Model = fleet standard gear by default** (e.g. `gpt-5.6-terra` medium;
   boost gear effort low). A higher gear is legitimate only while the fleet's
   model ledger holds an open entry for this lane.
4. **No lane registry file.** Truth = live `herdr pane list` + the issue
   tracker, cross-checked. A registry would be a second, drifting authority.

## If you are a worker lane

- Your tab/pane label names your issue. **Work on that issue only.** If you
  are asked (or tempted) to pick up another issue, refuse and report — the
  next issue gets its own lane.
- On completion: write your terminal receipt to the agreed inbox **first**,
  then stop all your background terminals (`/stop`), then park. Never leave a
  background process holding a shared lock (test-serialization locks etc.) —
  a leaked holder can starve the whole fleet.
- Never switch your own model. If you are stuck on the same failure
  repeatedly, say so in your report; the supervisor escalates via the ledger.

## If you are a supervisor / PO lane

### Assign (issue → lane)

1. Duplicate check: does any pane already carry this issue ID? If yes, message
   that pane instead of creating a new lane.
2. Create the lane with the fleet bootstrap procedure; pass the model
   explicitly; tab label starts with the issue ID.
3. Kickoff must state: "This lane is dedicated to <ISSUE-ID>. On completion,
   stop background terminals, then park. No other issue work."

### Close (issue closed → teardown)

Trigger on **tracker-measured** Done/Canceled (never on lane self-report):
verify no background processes survive (check shared-lock holders; stale-check
before killing), remove worktree/branch, **close** the pane (no
rename-and-reuse), close any open model-ledger entry.

### Audit sweep

Never audit from `pane list` alone — reuse drift leaves its only trace on the
tab layer (measured: pane label swapped to look current while the tab still
named a closed issue). Join `herdr tab list` × `herdr pane list` on `tab_id`,
extract issue IDs from both labels, and cross-check three ways: layer vs
layer, and both vs tracker state. Measure models from pane footers.

| Violation | Disposition |
|---|---|
| Orphan (no issue ID on either layer) | ask owner; close if unclaimed next sweep |
| Zombie (issue closed, lane alive) | teardown → close now |
| Duplicate writer (same issue, 2+ panes) | stop the later one |
| Unledgered boost | demote with `scripts/model-switch.sh` (menu measured, fail-closed); notify owner |
| Reuse drift (layers disagree / tab names closed issue) | identify real work; park → teardown; fresh lane for the next issue |
| In-progress issue with no lane | report to owner (do not assign on their behalf) |

Report once, at the end: workspace / pane / issue / violation / disposition —
or "swept N panes, 0 violations".

## Anti-goals

- No lane registry file. No "keep it just in case" for closed-issue lanes.
- No deferring an unledgered-boost demotion past the turn that found it.
- No blind menu-number presses when switching models — always derive the
  number from the measured menu (see `scripts/model-switch.sh`).
