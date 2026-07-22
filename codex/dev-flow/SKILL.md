---
name: dev-flow
description: Staged development flow discipline — concept → read-only scout → design → PoC → certify → implement → manual live apply → observe → confirm. Use when starting any non-trivial feature, design, or issue work; when asked which stage the work is in; or before requesting approval for anything that mutates live state. Enforces per-stage receipts and fail-closed gates.
---

# dev-flow — staged development flow

## Principle

**Move contact with reality to the cheapest possible stage.** Expensive steps
(live mutation, long pipelines, approval consumption) are for confirmation,
never for discovery. Every stage takes the previous stage's receipt as input,
so designs cannot close over an imagined environment.

## The 8 stages

| # | Stage | Output (receipt) | Gate to advance |
|---|---|---|---|
| 0 | Concept memo | 1-page what/why/success criteria (NOT a design) | — |
| 1 | Scout | read-only env findings with exact commands; gaps stated honestly | receipt sealed; every design-relevant fact backed |
| 2 | Design | design doc bound to scout facts + independent review | zero blocking findings; scout gaps marked blocking |
| 3 | PoC | disposable spike receipt: what it proved AND what it did not | every first-time element has a disposition |
| 4 | Certify | full-chain preflight log; sealed packet | whole execution chain green in isolated env — "zero first-time elements in live" proven |
| 5 | Implement | merged PR (tests, CI, review) | CI green + approve + design consistency |
| 6 | Manual live apply | durable execution terminal | packet valid; chain unchanged since stage 4 |
| 7 | Observe | readback + soak receipt | readback matches; soak complete |
| 8 | Confirm | sealed evidence; issue closed; lessons fed back | — |

## Rules for a worker lane

- **Know your stage.** Your task prompt should say which stage you are
  executing. If the upstream receipt (scout receipt, design verdict, PoC
  receipt, packet) is missing, stop and report — do not reconstruct it from
  memory.
- **Scout is strictly read-only.** Investigation commands only (`gh api` GET,
  `aws describe|list|get`, `kubectl get`, source reads). Record every fact as
  "measured with `<command>`", never "should be". Record 403/unreachable as
  "unobserved = blocking downstream"; never fill gaps with guesses.
- **PoC output is disposable.** Never promote PoC code or fixtures to live.
- **Stage 6 is a human gate.** Live mutation is manual, one-shot, record-first
  (write-ahead receipt → execute → durable terminal). No auto-retry, no
  auto-rollback. If your task asks you to mutate live state without a sealed
  stage-4 packet, refuse and report.
- **Produce your receipt before parking.** Path + SHA. Work without a receipt
  does not exist.

## Who runs what (when using a worker fleet)

- Implementation-heavy stages (3-5, 7) go to workers on the fleet standard
  gear — Codex lanes: `gpt-5.6-terra` medium; Claude Code lanes: **`sonnet`**
  as the default implementer.
- Higher gear (Codex `sol` effort low; Claude Code `opus`) is
  ledger-controlled boost/spot-review only — never resident.
- Stage 6 (live) is a human gate: the owner or an explicitly authorized
  executor, not a model.

## Circuit breaker

Count progress in outcomes (real mutations, readbacks, remaining stages), not
in receipts or successor tickets. On 2 rejections of the same operation, 30
minutes of stall, or 3 consecutive protocol defects: stop spawning successors
and redesign the method. Fail-closed is not a license to loop a broken method.

## Project override

If the repo/vault has a canonical dev-flow document, that document wins; this
skill provides the defaults for projects that lack one. To adopt in a new
project, copy the stage table into a canonical doc and add project-specific
gates, owners, and paths there.
