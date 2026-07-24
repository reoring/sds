---
name: dev-flow
description: Lightweight development flow — the default track for everyday work. source-only changes, dev/staging live applies, and zero-user production (owner-declared). Evidence is a merged PR + green CI + one ledger line; no sealing, no successor tickets, no verdict ping-pong. Routes irreversible or customer-visible work to prod-flow via a one-question track test. Keeps hollow-green defenses and a fix-plus-regression-gate rule for problems found live.
---

# dev-flow — lightweight development flow (default track)

**English** | [日本語](SKILL.ja.md)

## Principle (one line)

**Concentrate rigor at irreversible mutation gates; everywhere else, ship fast
and let CI + PR review + regression gates carry the discipline.** Ceremony that
duplicates a runtime fail-closed check is paying for the same safety twice.

This split was distilled from a real failure mode: a flow built for one-shot
irreversible launches (sealed receipts, successor tickets, verdict documents)
leaked into everyday development and made everything slow — while adding no
safety where it was applied.

## The track question (ask first, every time)

**"If this fails, do we lose a non-refundable consumable (approval, signature,
publication, quota) — or does a real customer see it?"**

- **No → this skill (lightweight, the default).**
- **Yes → [prod-flow](../prod-flow/SKILL.md)** — the full staged flow with
  packet sealing and a human GO gate.

Examples:

- Lightweight: source-only changes (PR/CI cycle), live applies to dev/staging
  estates, production with zero real users (owner-declared — see below).
- prod-flow: customer-visible production mutation, signing/publication
  semantics, org-level authority (account vending, permission changes),
  anything that consumes a one-shot tuple.

Never carry prod-flow equipment (packets, sealing, successor tickets,
write-ahead receipts) into the lightweight track.

## Lightweight rules

- **No sealing, no receipt-SHA reporting, no successor tickets.** A failure
  means: fix it and run again.
- Evidence = merged PR + green CI + one appended line in the project ledger
  (CHANGELOG/EVENT or equivalent).
- Scout = look (read-only) and paste your notes into the issue. Read-only
  discipline still applies; guessing instead of looking is still forbidden.
- PoC and certification collapse into "show it working once in an isolated
  environment" — necessity at the implementer's discretion.
- After a live apply, leave a one-line readback (the fact, no ceremony).
- No state file. The issue / PR is the source of truth.

## What is NOT cut (real gates, not ceremony)

- **Hollow-green defenses.** Test ownership separation (RED tests written and
  owned by a different lane; any implementer diff to tests = instant
  rejection), a held-out test at review, and real-boundary green as the merge
  gate. A fake environment cannot tell an honest implementation from a hollow
  one.
- **1 issue = 1 lane** (issue-lane skill).
- **Environment identification is measured, not assumed** — estate mix-ups are
  an accident class unrelated to speed, and cutting ceremony does not license
  cutting this.

## Zero-user production (owner-declared exception)

Production with no real users may run on this track by explicit owner ruling.
The trade is a single rule:

- **A problem found live is closed only with fix + a recurrence gate**
  (regression test / QA walk / harness addition) in the same change.
- The same problem appearing live twice = the gate is defective → circuit
  breaker: stop and redesign the gate, don't just try harder.
- The exception expires the day real users arrive. Expiry is declared by the
  owner, never assumed.

This flips the discipline from pre-emptive ceremony to post-hoc hardening:
release fast, find problems live, make each one structurally unrepeatable.

## Review rules (no verdict ping-pong)

- No CONFORMS / NOT-CONFORMS verdict documents on this track. Review = PR
  approve / request-changes with inline comments.
- Reviewers state **all blocking findings in the first pass** (no
  drip-feeding). A late blocking finding that was visible in round 1 is a
  reviewer defect (breakage newly introduced by rework is exempt).
- Re-review checks **only the delta** of the requested changes.
- **Two rounds without convergence = circuit breaker**: stop the async
  ping-pong; put reviewer and implementer in one conversation, or have the
  owner adjudicate the remaining points.

## Circuit breaker

Count progress in outcomes (merged PRs, readbacks) — not process artifacts. On
2 rejections of the same operation, 30 minutes of stall, or a second
hollow-green from the same lane: stop and change the method (re-slice the
issue, switch to contract-test-first, or apply a ledger-controlled gear boost).

## Project adaptation

If the project has its own canonical flow document, that document wins; this
skill is the default for projects without one. Pair it with
[prod-flow](../prod-flow/SKILL.md) for the heavy path, and record the track
ruling ("what counts as consumable / customer-visible here") in the project's
canonical doc as it accumulates.
