---
name: issue-lane
description: "1 issue = 1 lane" lifecycle discipline for herdr-managed agent fleets. Use when assigning an issue to a worker lane, when an issue closes ("close the lane too"), or for lane audits ("lane audit", "lane stocktake", "1-issue-1-lane check"). Creates lanes with issue-ID labels on BOTH the tab and the pane, tears lanes down when their issue closes, and audits drift by three-way cross-checking tab label × pane label × issue tracker state.
---

# issue-lane — 1 issue = 1 lane lifecycle discipline

Lane creation, teardown, and model escalation each have their own canonical
procedures (bootstrap / teardown / model-gear conventions of your fleet). This
skill binds them to the **issue lifecycle** and provides **drift detection**.

## Why

Observed failure modes in a multi-PO agent fleet: lanes kept an expensive
model from a previous boost and carried it into unrelated work; lanes for
closed issues lingered and made the fleet unreadable; lanes were silently
reused across issues by relabeling the pane, leaving the stale truth only on
the tab. Binding lanes 1:1 to issues makes `pane list` equivalent to "what is
actually in progress" — management returns to measurement.

## Invariants (4)

1. **1 issue = 1 lane = 1 writer.** Labels carry the issue ID on **both
   layers**:
   - **tab label**: first word = `<ISSUE-ID>` (e.g. `PROJ-123 api-freeze`)
   - **pane (agent) label**: `<space>/<ISSUE-ID>[-role]` (e.g. `api/PROJ-123`)

   If the two layers disagree about the issue, that is **reuse drift** (the
   pane label was swapped while the lane kept working on something else).
   Resident PO panes (tab label `po`) are exempt.
2. **A lane lives exactly as long as its issue.** Born at assignment, torn
   down when the issue reaches Done/Canceled. "Reuse for the next issue" is
   forbidden — the next issue gets a fresh lane (model, history, and worktree
   start clean).
3. **Model = fleet standard gear by default** (example: `gpt-5.6-terra`
   medium; boost gear effort low). Running on a higher gear is allowed only
   while a model ledger has an open entry for the lane. Unledgered high gear
   is demoted on sight.
4. **No lane registry file.** The source of truth is `herdr pane list` (live)
   cross-checked with the issue tracker. A registry file would become a
   second, drifting authority.

## Assign (issue → lane)

1. **Duplicate check**: `herdr pane list` for the target workspace — if a pane
   already carries this issue ID, do not create another; message that pane.
2. **Create** via your fleet's lane-bootstrap procedure. Pass the model
   explicitly (never rely on defaults). Tab label starts with the issue ID.
3. **Kickoff message** (sent to the pane ID) must include:

   > This lane is dedicated to <ISSUE-ID>. On completion, stop all background
   > terminals, then park and report. Do not work on any other issue.

## Close (issue closed → lane teardown)

Trigger: PR merged + issue Done/Canceled **measured in the tracker** (Linear
MCP `get_issue`, `gh issue view`, etc.) — never on the lane's self-report.

1. Confirm issue state in the tracker.
2. Teardown safely: verify no background processes remain (especially holders
   of shared locks), stale-check before killing, then remove worktree/branch.
3. **Close the pane** (do not rename-and-reuse — that is how label/issue drift
   starts).
4. If the lane held a model-ledger boost entry, close the entry.

## Audit sweep ("lane audit")

**Never audit from `pane list` alone.** Measured lesson: a pane label looked
current while the tab label still named a closed issue — cross-issue reuse
left its only trace on the tab layer.

1. `herdr workspace list`, then per workspace take BOTH `herdr tab list` and
   `herdr pane list`, joined on `tab_id`.
2. Extract issue IDs from tab label and pane label; cross-check (a) the two
   layers against each other and (b) against the tracker state (three-way).
3. Measure the model from the pane footer:
   ```bash
   herdr pane read <pane> --source visible --lines 3 --format text | tail -1
   ```
4. Violations and dispositions:

| Violation | Detection | Disposition |
|---|---|---|
| Orphan lane | no issue ID on either label layer | ask the owning PO; close if still unclaimed next sweep |
| Zombie lane | issue Done/Canceled but pane alive | teardown → close immediately |
| Duplicate writer | same issue ID on 2+ panes | stop the later one; consolidate into the first |
| Unledgered boost | footer shows high gear, no open ledger entry | demote via `scripts/model-switch.sh` (fail-closed; no blind menu numbers), notify the owning PO |
| Reuse drift | tab and pane disagree, or tab names a closed issue | identify the real work item; if working, wait for park → teardown; next issue gets a fresh lane |
| Unassigned work | issue In Progress with no lane | report to the owning PO (do not create lanes on their behalf) |

5. Report in one final message: workspace / pane / issue / violation /
   disposition. If clean, say "swept N panes, 0 violations" with the count.

## Anti-goals

- No lane registry file (live measurement + tracker are the SOT).
- No keeping closed-issue lanes around "just in case".
- No deferring an unledgered-boost demotion — finish it in the turn that
  found it.
- No overriding the owning PO's assignment judgment (the sweep detects and
  applies mechanical dispositions only).
