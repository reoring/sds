---
name: dev-flow
description: Staged development flow discipline — concept → read-only scout → design → PoC → certify → implement → manual live apply → observe → confirm. Use when starting any non-trivial feature, design, or issue work; when asked "which stage is this in?"; for gate checks before advancing; or before anything that would mutate live/production state. Provides a per-effort state file, fail-closed gates, and receipt templates. Trigger phrases: "dev-flow", "start the flow", "gate check", "which stage", "can we advance?".
---

# dev-flow — staged development flow

**English** | [日本語](SKILL.ja.md)

## Principle (one line)

**Move contact with reality to the cheapest possible stage.** Expensive steps
(live mutation, long pipelines, approval consumption) are for confirmation,
never for discovery. Every stage takes the previous stage's receipt as input,
which prevents designs from closing over an imagined environment.

This flow was distilled from real failure patterns: designs written against an
imagined environment that collapsed on first ground-truth contact; hour-long
release pipelines burned repeatedly as a debugging loop; production one-shot
attempts consumed by defects that a cheap local chain test would have caught.

## The 8 stages

| # | Stage | Output (receipt) | Gate to advance |
|---|---|---|---|
| 0 | Concept memo | 1 page: what / why / success criteria (NOT a design — it scopes the scout) | — |
| 1 | Scout | read-only environment findings with exact commands; gaps recorded honestly | receipt sealed; every design-relevant fact is backed by it |
| 2 | Design | design doc bound to scout facts + independent review verdict | zero blocking findings; scout gaps explicitly marked blocking |
| 3 | PoC | disposable spike receipt: what it proved AND what it did not prove | every first-time element has a disposition |
| 4 | Certify | full-chain preflight log + sealed packet | entire execution chain green in an isolated env — "zero first-time elements in live" is proven |
| 5 | Implement | merged PR (tests, CI, review) | CI green + review approve + consistency with the design |
| 6 | Manual live apply | durable execution terminal (record-first) | stage-4 packet still valid; chain unchanged since sealing |
| 7 | Observe | readback + soak receipt (measured values, unobserved areas) | readback matches; soak completed |
| 8 | Confirm | sealed evidence, issue closed, lessons fed back into the flow doc | — |

Absolute rules per stage:

- **Scout is strictly read-only.** Record facts as "measured with `<command>`",
  never "should be". Record 403 / unreachable as "unobserved = blocking
  downstream" — never fill gaps with guesses.
- **PoC output is disposable.** Never promote PoC code or fixtures to live.
- **Live apply is manual, one-shot, record-first**: write-ahead attempt receipt
  → execute once → durable terminal. No auto-retry, no auto-rollback.
- **Observability is designed in stage 2.** Bolting on observation after going
  live is a design defect, not an operations task.

## State file

One file per effort: `flow/<topic>-flow.md` in the working directory. This is
the single source of truth for the effort's flow position.

```markdown
# flow: <topic>
- started: <date> / owner: <lane or person>
- current stage: <N>. <name>

| stage | status | receipt (path + SHA) | notes |
|---|---|---|---|
(rows 0-8)

## Rollback history
- <date> stage N -> M: <one-line reason>
```

Update it on every advance/rollback. The receipt column takes **path + SHA**.
"Verbally done" is not done.

## Rollback table

| Where the mismatch surfaced | Go back to |
|---|---|
| Design review finds an assumption not in the scout | 1 (re-scout or fix design) |
| PoC breaks a design hypothesis | 2 |
| Certification finds an unverified chain segment | 3 |
| Implementation diverges from design assumptions | 2 (revise the design — no ad-hoc patching) |
| Live apply fails (durable terminal remains) | 4 (reissue packet, re-examine method) |
| Observation finds a problem | adjudicate (2, 5, or 6) — never auto-rollback |

**If you want to advance without meeting the gate**: the gate is not wrong —
something upstream is. Find the rollback target instead.

## Who runs what (when using a worker fleet)

- Implementation-heavy stages (3-5, 7) go to workers on the **fleet standard
  gear** (examples: `gpt-5.6-terra` medium on a Codex fleet; **`sonnet`** as
  the default implementer on a Claude Code fleet).
- Higher gear (Codex `sol` effort low; Claude Code `opus`) is reserved for
  "stuck-breakthrough" boosts and blocking spot reviews, **ledger-controlled**
  (see a model-gear ledger convention) — never resident.
- Stage 6 (live) is a **human gate**: the owner or an explicitly authorized
  executor, not a model.
- Lane creation/lifetime follows the issue-lane skill (1 issue = 1 lane).

## Circuit breaker

Count progress in outcomes (real mutations, readbacks, remaining stages) — not
in receipts or successor tickets. On 2 rejections of the same operation, 30
minutes of stall, or 3 consecutive protocol defects: stop, forbid the next
attempt, and redesign the method. Fail-closed is not a license to loop a
broken method forever.

## Project adaptation

If the project has its own canonical flow document, that document wins; this
skill is the default for projects without one. To adopt it, copy the stage
table into a canonical doc in the project and accumulate project-specific
gates, owners, and path conventions there.
