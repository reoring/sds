---
name: main-po-patrol
description: The main PO's patrol over the fleet's project POs — check each PO session's health (context usage, degradation symptoms, forced model switches) and drive session rotation via /po-handover → /po-resume where needed. The subjects are POs, not lanes. Triggers - "main PO patrol", "check on the POs", "PO health sweep", "PO context check".
---

# main-po-patrol — patrolling the POs

**English** | [日本語](SKILL.ja.md)

When one person runs many projects, each project has a PO session — and
someone must watch the watchers. The **main PO** is a PO of POs: it supervises
PO sessions themselves and drives their rotation. **Its subjects are POs, not
lanes** — lanes belong to each project PO. The main PO touches a lane only as
emergency proxy when that PO is dead (recorded in the ledger).

## 0. Principles

- Take the real time (`date +%H:%M`) before starting — no mental arithmetic.
- Consolidate the report into the final message of the turn.
- Patrol is read-only by default. The only mutations: driving a rotation, and
  appending to the roster/ledger.
- **Leave self-running POs alone. The best main PO is idle.**

## 1. Measure the PO roster (every patrol, no skipping)

```bash
herdr pane list | jq -r '.result.panes[] | select(.agent=="claude") | [.pane_id, .agent_status, .cwd] | @tsv'
```

Cross-check against `<main-po-dir>/po-roster.md` (space → PO pane map; create
on first patrol):

- Roster pane gone or replaced → update the roster from measurement.
- Unrostered PO-looking pane (cwd in a PO operations dir) → ask it, then add.
- **Never send to a pane ID from a snapshot** — re-measure right before sending.

## 2. Health-check each PO

For each rostered PO:

```bash
herdr pane read <pane> --source visible --lines 5 --format text   # statusline + current state
herdr pane read <pane> --source recent --lines 20 --format text   # substance of recent turns
```

**Three things to look at**: ① context usage (read the statusline % if shown;
ask via message only when health is already in doubt — no routine polling of
all POs), ② degradation symptoms (declaration stall: plan-only turns with zero
diffs ×3; hollow output; sluggish replies), ③ discontinuous confusion — a PO
that was fine suddenly wrong at a turn boundary.

**Judgment table**:

| Observation | Verdict | Action |
|---|---|---|
| Running fine | — | leave alone |
| Context 50–60% | rotation age | drive rotation (§3); if a live gate / one-shot is mid-flight, wait for its terminal first |
| < 50% but a gate just closed | natural boundary | recommend rotation (don't force — PO's call) |
| Gradual degradation symptoms | context rot | rotate now (free refresh before paid boost) |
| **Discontinuous confusion** (sudden) | **suspect a forced model switch first** | measure the statusline's model. If switched, a normal rotation (handover → /clear → /po-resume) suffices — /clear restores the configured default model. Keep the parallel suspicion of context rot (doubt both). Whether to continue or restore is the owner's call |
| Unresponsive / dead | PO absent | start a new session from the latest handover and /po-resume. If the handover is too stale: emergency proxy (ledger it) + rebuild |

## 3. Driving a rotation (only for flagged POs)

1. **Precondition**: the PO is not mid-live-gate / mid-mutation (rotating
   there creates "may have sent" ambiguity).
2. Message the PO to run `/po-handover` (sender identified, one line, no blind
   resends).
3. **Verify the handover file for real**: exists, and in-flight / monitor
   re-arm list / inbox baseline are filled. Mostly blank → send it back.
4. Send `/clear` to the same pane (the model returns to the configured default
   — this also cures a forced switch). If delivery is unconfirmed, look at the
   pane instead of resending blindly.
5. Send `/po-resume <handover-path>` to the new session.
6. **Watch it through** to "state rebuilt from live measurement + monitors
   re-armed" (don't let it resume work having merely read the handover). The
   re-arm Bash calls often stall on an approval prompt in a fresh session —
   verify the command matches the handover's re-arm list exactly, then
   approve. No blind approvals; if it doesn't match, ask the pane why.
7. One ledger line: datetime / space / trigger type (context% | boundary |
   symptom | model).

## 4. Inbox and seam sweep

- Process escalations in `<main-po-dir>/inbox/`: decidable by the project's
  design compass → send back; cross-space → adjudicate + ledger; owner-only →
  escalate immediately.
- Cross-space seams: violations of fleet-wide freezes, contention on shared
  resources. Dig only when something is actually there.

## 5. Report (one final message)

Order: ① needs-owner decisions / incidents, ② rotations driven (space,
trigger), ③ model switches detected, ④ escalations handled / remaining,
⑤ per-PO deltas (changed ones only). All healthy → three lines suffice.

## Anti-goals

- **No direct lane intervention** — lanes are each PO's territory.
- No routine status collection — read state from panes/receipts/ledgers.
- No forced "just in case" rotation of a healthy PO — refresh is free, but
  interruption is not. Recommending at a boundary is fine.
- No rewriting roster/canon every patrol — only on diffs.
- No new mechanisms; gaps get fixed by amending this skill and the main-PO
  canon doc.
