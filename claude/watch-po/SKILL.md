---
name: watch-po
description: Event-driven detection of stalled or abnormal PO panes, reported to the main PO — approval-prompt stalls (POPROMPT), context threshold crossings (POCTX), forced model switches (POMODEL), pane disappearance (PODEAD) — via a persistent Monitor, optionally pushed to a notification topic. The standing sensor that fills the gaps between main-po-patrol rounds. Triggers - "arm the PO watch", "watch-po", "tell me when a PO stalls".
---

# watch-po — event watch for PO stalls and anomalies

**English** | [日本語](SKILL.ja.md)

If `main-po-patrol` is the periodic round, this is the **standing sensor
between rounds**. Born from a real incident: two freshly rotated PO sessions
stalled on approval prompts during monitor re-arming, and the human owner
noticed before the main PO did — twice. The main PO should notice first.

## Events (all deduplicated — emitted on transition only)

| Event | Meaning | Main PO's first move |
|---|---|---|
| `POPROMPT <label> <pane>` | stalled waiting for approval/input | look at the pane → verify the command against the handover/canon, then approve or reject (no blind approvals) |
| `POCTX <label> <pane> <pct>%` | context crossed the threshold (default 60%) | check for a mid-flight live gate → drive rotation (main-po-patrol §3) |
| `POMODEL <label> <pane> <from>-><to>` | the statusline's model changed | measured platform behavior: models can be switched out silently. Owner decides continue vs. restore |
| `PODEAD <label> <pane>` | pane disappeared | rebuild from the latest handover |
| `POBACK <label> <pane>` | recovered from PROMPT/DEAD | record only |
| `WATCH ERROR <msg>` | the watch itself is failing | check herdr |

## Arming (from the main PO session)

1. Read the PO panes from the roster (**re-measure with `herdr pane list`
   right before arming** — pane IDs drift; fix the roster first if it
   disagrees).
2. Start under a persistent Monitor:

```bash
bash <skill-dir>/scripts/watch-po.sh \
  --pane <paneId>=<space>/po [--pane ...] \
  --ctx-threshold 60 --interval 30 [--ntfy <topic>]
```

Labels must be **`<space>/po` form** — the human owner reads labels, not pane
IDs (pane IDs appear in parentheses as an aid). Give the herdr pane itself the
same label (`herdr pane rename <pane> '<space>/po'`).

3. `--ntfy <topic>` pushes each event to `ntfy.sh/<topic>` as well (events are
   deduplicated, so the volume is low).
4. After arming, add one ledger line — and put the watch on your **own
   handover's monitor re-arm list** (monitors die with the session).

## Discipline on receiving events

- **POPROMPT first** — a PO's clock is stopped. But approve only after
  looking at the pane and matching the command against the handover/canon.
- POCTX is not "rotate immediately" — wait for the terminal if a live gate /
  one-shot is mid-flight.
- POMODEL: never switch the model back on your own — the owner decides based
  on load (a light-load PO may simply continue).
- Ledger one line per handled event. POBACK is record-only.

## Constraints (know these)

- Detection greps the **visible screen** — a prompt that scrolled away in an
  instant is missed (in practice approval prompts sit on screen until
  answered, so they are not missed).
- The statusline must show the model name and a `[ctx:NN%]` field — adapt the
  regex in the script to your statusline format.
- POMODEL's baseline is the first observation after arming; a switch that
  happened **before** arming is invisible — the patrol's model sweep covers
  that.
- A rotation that replaces the pane (new-pane style) requires re-arming; the
  same-pane `/clear` style does not (pane ID unchanged).

## Anti-goals

- Do not retire the patrol — the watch only sees "stopped". "Running but not
  progressing" (declaration stalls, hollow output) is only caught by actually
  reading panes on patrol.
- Do not add worker lanes as subjects — lanes belong to each PO's
  herdr-event-watch.
