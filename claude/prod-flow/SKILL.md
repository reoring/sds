---
name: prod-flow
description: Full-rigor staged flow for irreversible or customer-visible work — concept → read-only scout → design → PoC → certify → implement → manual live apply → observe → confirm. Use when a failure would consume a non-refundable consumable (approval, signature, publication, quota) or be visible to a real customer. Provides packet sealing (GO bound to a packet digest), per-stage receipts, fail-closed gates, review round limits, and a circuit breaker. For everyday work use dev-flow instead. Trigger phrases: "prod-flow", "full track", "packet", "gate check", "can we advance?".
---

# prod-flow — full-rigor staged flow

**English** | [日本語](SKILL.ja.md)

## When this applies (and when it doesn't)

Ask the track question first:

**"If this fails, do we lose a non-refundable consumable (approval, signature,
publication, quota) — or does a real customer see it?"**

- **Yes → this skill.** Customer-visible production mutation,
  signing/publication semantics, org-level authority (account vending,
  permission changes), anything consuming a one-shot tuple.
- **No → [dev-flow](../dev-flow/SKILL.md)** (lightweight, the default).
  Running this flow on everyday work is how process weight accidents happen —
  the equipment below exists for launches, not for iteration.

## Principle (one line)

**Move contact with reality to the cheapest possible stage.** Expensive steps
(live mutation, long pipelines, approval consumption) are for confirmation,
never for discovery. Every stage takes the previous stage's receipt as input,
which prevents designs from closing over an imagined environment.

This flow was distilled from real failure patterns: designs written against an
imagined environment that collapsed on first ground-truth contact; hour-long
release pipelines burned repeatedly as a debugging loop; production one-shot
attempts consumed by defects that a cheap local chain test would have caught;
and an ambiguous verbal approval that executed something other than what was
approved.

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

## The packet (stage-4 output)

A packet is the **launch procedure document, not the payload**: it fixes what /
where / how, exactly once, with zero room for judgment.

- Contents, all bound numerically: exact source SHA, full inventory of
  artifacts with digests, execution order, an explicit "touch nothing else"
  list, and the stop condition on any deviation.
- When filled in, the whole document's hash (**packetDigest**) is computed.
  Independent review and the owner's GO are issued **against that digest** —
  "approved something vague, executed something else" becomes structurally
  impossible.
- The executor reads the packet and performs it exactly once. Mid-flight
  "while I'm here" fixes are forbidden; any deviation = STOP with a durable
  terminal, then roll back to stage 4 (reissue the packet).

Think of it as a rocket launch checklist: the payload is identified by digest,
and the paper says under exactly which conditions it may be launched.

## Review round limits (no verdict ping-pong)

Independent review is required at stages 2 and 4, but rounds are capped:

- **All blocking findings in the first pass** (no drip-feeding). A late
  blocking finding that was visible in round 1 is a reviewer defect (breakage
  newly introduced by rework is exempt).
- **Re-review checks only the delta** of the requested changes — no full
  re-review per round. Exact-SHA binding applies once, at final sealing.
- **Two rounds without convergence = circuit breaker**: stop the async
  ping-pong; put reviewer and implementer in one conversation, or have the
  owner adjudicate the remaining points.

## Hollow-green defenses (stage 5)

A worker can satisfy tests with a skeleton: "green" is a proxy metric, and
cheaper models optimize the proxy literally (we caught this repeatedly in
production). Defenses, all battle-tested:

- **Test ownership separation (contract-test-first).** RED tests are written
  and owned by a different, stronger lane, on the production path, failing for
  real; the implementer's only job is to turn them green. **Any implementer
  diff to the tests = instant rejection.**
- **Real-boundary green.** Fake-client / pure-unit green counts only as
  stage-3 (PoC) evidence; the stage-5 merge gate requires green on a
  real-boundary harness (e.g. a real API server). A fake environment cannot
  tell an honest implementation from a hollow one — this is a structural
  ceiling, not a diligence issue.
- **Held-out test.** At review, add and run one test the implementer never
  saw. A skeleton fails it; an implementation of the spec passes. One line in
  the review procedure, and the cheapest strong detector.
- **Second hollow-green from the same lane is a circuit-breaker event.** Stop
  and change the method — switch to contract-test-first, apply a
  ledger-controlled boost, or re-slice the issue. It signals oversized scope,
  a broken gate, or insufficient gear, not laziness.
- **Gates must allow honest green.** When reviewing a test gate (stage 2),
  check that a truthful implementation can actually pass in the gate's
  environment — a gate where honest green is impossible induces fabrication.

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
gates, owners, and path conventions there. Record the project's track ruling
("what counts as consumable / customer-visible here") in the same doc.
