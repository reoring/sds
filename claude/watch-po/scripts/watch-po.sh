#!/usr/bin/env bash
# watch-po — emit "stalled / abnormal" events for a set of PO panes as an
# event stream on stdout. Meant to run under the main PO's persistent Monitor.
# The PO-flavored sibling of herdr-event-watch.
#
# Usage:
#   watch-po.sh --pane <paneId>=<label> [--pane ...] \
#     [--interval <sec>] [--ctx-threshold <pct>] [--ntfy <topic>] [--once]
#
# Emitted lines (1 line = 1 event, on transition only = deduplicated):
#   POPROMPT <label> <pane>             ... entered an approval/input wait (highest priority)
#   POCTX <label> <pane> <pct>%         ... context usage crossed the threshold (rotation age)
#   POMODEL <label> <pane> <from>-><to> ... the statusline's model changed (forced-switch detection)
#   PODEAD <label> <pane>               ... pane vanished from pane list
#   POBACK <label> <pane>               ... recovered from PROMPT/DEAD
#   WATCH ERROR <msg>                   ... the watch itself is persistently failing
#
# Policy:
#   - Ignore working<->idle flapping. Only "stopped waiting for a human" states are picked up.
#   - Model baseline is the first observation; emit only on change (a /clear restore also emits).
#   - With --ntfy, push each emit to ntfy.sh/<topic> (events are deduplicated, so low volume).
#   - A transient herdr failure must not kill the loop; only persistent failure emits WATCH ERROR.
#
# NOTE: the statusline regex below expects a line like
#   user@host:... (Fable ...) [ctx:NN%]
# Adapt the (Fable|Opus|Sonnet|Haiku) pattern and [ctx:NN%] field to your
# statusline format.

set -u

INTERVAL=30 CTX_THRESHOLD=60 NTFY="" ONCE=0
PANES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --pane)          PANES+=("$2"); shift 2;;
    --interval)      INTERVAL="$2"; shift 2;;
    --ctx-threshold) CTX_THRESHOLD="$2"; shift 2;;
    --ntfy)          NTFY="$2"; shift 2;;
    --once)          ONCE=1; shift;;
    *) echo "WATCH ERROR unknown arg: $1"; exit 64;;
  esac
done
[ ${#PANES[@]} -eq 0 ] && { echo "WATCH ERROR --pane is required (paneId=label)"; exit 64; }
[ "$INTERVAL" -lt 5 ] && INTERVAL=5

emit() {
  echo "$*"
  if [ -n "$NTFY" ]; then
    curl -s -m 10 -d "[watch-po] $*" "https://ntfy.sh/${NTFY}" >/dev/null 2>&1 || true
  fi
}

# Per-pane state: prompt=0/1, dead=0/1, ctxhigh=0/1, model=<baseline>
declare -A ST_PROMPT ST_DEAD ST_CTXHIGH ST_MODEL
herdr_fail=0

while :; do
  alive=$(herdr pane list 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(1)
for p in d.get("result",{}).get("panes",[]):
    print(p.get("pane_id",""))
')
  if [ -z "$alive" ]; then
    herdr_fail=$((herdr_fail+1))
    [ "$herdr_fail" -ge 5 ] && { emit "WATCH ERROR herdr pane list failed ${herdr_fail}x"; herdr_fail=0; }
  else
    herdr_fail=0
    for spec in "${PANES[@]}"; do
      pane="${spec%%=*}"; label="${spec#*=}"
      # --- liveness ---
      if ! grep -qx "$pane" <<<"$alive"; then
        if [ "${ST_DEAD[$pane]:-0}" != "1" ]; then
          ST_DEAD[$pane]=1; emit "PODEAD $label ($pane)"
        fi
        continue
      fi
      if [ "${ST_DEAD[$pane]:-0}" = "1" ]; then
        ST_DEAD[$pane]=0; emit "POBACK $label ($pane) pane restored"
      fi

      view=$(herdr pane read "$pane" --source visible --lines 40 --format text 2>/dev/null) || continue

      # --- approval prompt / input wait ---
      if grep -qE 'requires approval|Do you want to proceed\?|Esc to cancel' <<<"$view"; then
        if [ "${ST_PROMPT[$pane]:-0}" != "1" ]; then
          ST_PROMPT[$pane]=1; emit "POPROMPT $label ($pane) stalled on approval/input"
        fi
      else
        if [ "${ST_PROMPT[$pane]:-0}" = "1" ]; then
          ST_PROMPT[$pane]=0; emit "POBACK $label ($pane) prompt cleared"
        fi
      fi

      # --- model and ctx% from the statusline ---
      sl=$(grep -E '^\s*\S+@\S+:.*\((Fable|Opus|Sonnet|Haiku)[^)]*\)' <<<"$view" | tail -1)
      if [ -n "$sl" ]; then
        model=$(grep -oE '\((Fable|Opus|Sonnet|Haiku)[^)]*\)' <<<"$sl" | tail -1 | tr -d '()')
        ctx=$(grep -oE '\[ctx:[0-9]+%\]' <<<"$sl" | grep -oE '[0-9]+' || true)

        if [ -n "$model" ]; then
          base="${ST_MODEL[$pane]:-}"
          if [ -z "$base" ]; then
            ST_MODEL[$pane]="$model"
          elif [ "$model" != "$base" ]; then
            emit "POMODEL $label ($pane) ${base} -> ${model}"
            ST_MODEL[$pane]="$model"
          fi
        fi

        if [ -n "$ctx" ]; then
          if [ "$ctx" -ge "$CTX_THRESHOLD" ]; then
            if [ "${ST_CTXHIGH[$pane]:-0}" != "1" ]; then
              ST_CTXHIGH[$pane]=1; emit "POCTX $label ($pane) ctx ${ctx}%"
            fi
          else
            ST_CTXHIGH[$pane]=0
          fi
        fi
      fi
    done
  fi

  [ "$ONCE" = "1" ] && exit 0
  sleep "$INTERVAL"
done
