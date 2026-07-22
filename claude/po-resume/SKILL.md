---
name: po-resume
description: Resume a PO session from a /po-handover file. Read the handover as a map, rebuild state from live measurement, re-arm monitors, and load the standard PO toolkit (dev-flow / issue-lane / herdr-event-watch plus your fleet's ledger and messaging conventions) into working awareness before doing any PO work. Triggers - "po-resume", "resume the PO session", "take over as PO". Argument - path to the handover file.
---

# po-resume — PO session rotation (receiving side)

**English** | [日本語](SKILL.ja.md)

**Principle: the handover is a map, not a memory.** Inherit pointers and the
in-flight list — never the previous session's beliefs. Re-measure everything
live, in this order.

## Procedure (in order)

### 1. Read the handover

The path given as argument (default: `<po-dir>/handover/<space>.md`). Take:
① in-flight items (gates / expected verdicts / promises), ② the monitor
re-arm list, ③ the inbox baseline, ④ canonical pointers.

### 2. Read the canon (via the pointers)

Operations doc → ledgers (model ledger, decision ledger) → flow canon
(dev-flow doc, design principles). For large files, read the needed sections,
not the whole file.

### 3. Load the standard toolkit into working awareness (mandatory — do not skip)

A fresh session may *know* the skills exist without having them loaded into
its *decisions*. Confirm each explicitly and state "toolkit confirmed" in the
resume report:

| Skill | Where it serves PO work |
|---|---|
| **dev-flow** | Stage management and gate checks — especially stage-5 hollow-green defenses (zero test diffs from the implementer / held-out test / real-boundary green) |
| **issue-lane** | Lane assignment, teardown, audits. 1 issue = 1 lane, two-layer labels (tab × pane), lane dies with its issue, session rotation for degraded lanes (free refresh before paid boost) |
| **herdr-event-watch** | Re-arming watchers (step 5) and event-driven supervision. INBOX is primary, LANE is backstop, "a notification means look, not believe" |
| your model ledger convention | Boost/demotion bookkeeping; stall signatures (repeated failure, no-progress working, **declaration stall**: plan-only turns with zero diffs) |
| your messaging procedure | Reliable delivery to panes (beware unsubmitted composer text); address panes by pane ID |
| your patrol routine | The time-based backstop for when event watching dies |

### 4. Re-measure live (do not trust the handover)

- `herdr workspace list`, then the owned space's `herdr tab list` ×
  `herdr pane list` joined on tab_id (the issue-lane three-way check).
- Tracker state of every in-flight issue (detect movement since the handover
  was written).
- Sweep the inbox past the baseline: everything newer than the recorded
  filename goes on the processing queue.
- Cross-check the model ledger's open entries against measured pane footers
  (catch unledgered boosts).

### 5. Re-arm the monitors

Re-arm per the handover's list. **Sweep manually right after re-arming**
(arrivals during the gap are never emitted — a known trap). If the list says
"none" but the space has active lanes, do not run unwatched: arm at least one
watcher or confirm the patrol cron.

### 6. Record the succession

- Move the handover to `<po-dir>/handover/archive/<space>-<datetime>.md`.
- Post one line to the inbox / notification channel: "PO resumed (<space>,
  N in-flight items accepted)" — a durable record of who the PO is now
  (prevents cross-PO misattribution).

### 7. Resume report (final message)

One message to the owner: ① toolkit confirmed, ② monitors re-armed,
③ what the sweep found, ④ the accepted in-flight list with a next action per
item, ⑤ any discrepancy between the handover and live measurement (report the
previous session's misbeliefs honestly).

## Anti-goals

- Never treat handover statements as facts without re-measurement.
- Never skip step 3 by "having read it" — preventing the 60%-confusion relapse
  depends on the toolkit being loaded, not merely known.
- No heavy adjudications right after resuming — finish steps 1-6 first.
