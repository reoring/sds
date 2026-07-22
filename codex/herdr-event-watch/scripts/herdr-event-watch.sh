#!/usr/bin/env bash
# herdr-event-watch — emit herdr lane state transitions, PR required-check
# finalizations, and durable-artifact (inbox file) arrivals as an event
# stream on stdout. Designed to be launched from a persistent watcher
# (Claude Code Monitor tool, or a Codex background terminal).
#
# Usage:
#   herdr-event-watch.sh --workspace <wsId> [--prefix <laneLabelPrefix>] \
#     [--inbox <dir>] [--inbox-prefix <filePrefix>] \
#     [--repo <owner/repo> --check <checkName> --pr <n> [--pr <n> ...]] \
#     [--interval <sec>] [--once]
#
# Emitted lines (1 line = 1 event):
#   INBOX <filename>                 ... new file arrived in inbox (durable artifact — never missed)
#   LANE <label>=done|blocked        ... lane transitioned into that state (sampled — transients can be missed)
#   CI PR#<n> <check> -> pass|fail   ... PR required check finalized (once per PR+result+head)
#   WATCH ERROR <msg>                ... the watch itself is persistently failing (herdr unreachable etc.)
#
# Two-layer design (see SKILL.md, "done is transient" trap):
#   - Artifact-driven flows (waiting for terminal receipts / verdicts) should
#     treat INBOX as primary. Files do not disappear, so they are detected
#     regardless of poll interval.
#   - LANE done/blocked is sampled and can vanish between polls (measured
#     twice in production, 2026-07-21). Use it as a backstop for stall or
#     blocked detection.
#
# Policy:
#   - Do not emit working<->idle flapping (noise suppression). done/blocked only.
#   - Emit CI pass AND fail (silence != success).
#   - A transient gh/herdr failure must not kill the loop. Only persistent
#     failure emits WATCH ERROR.

set -u

WORKSPACE="" PREFIX="" REPO="" CHECK="cloud" INTERVAL=10 ONCE=0
INBOX_DIRS=() INBOX_PREFIX="" PRS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --workspace)    WORKSPACE="$2"; shift 2;;
    --prefix)       PREFIX="$2"; shift 2;;
    --inbox)        INBOX_DIRS+=("$2"); shift 2;;
    --inbox-prefix) INBOX_PREFIX="$2"; shift 2;;
    --repo)         REPO="$2"; shift 2;;
    --check)        CHECK="$2"; shift 2;;
    --pr)           PRS+=("$2"); shift 2;;
    --interval)     INTERVAL="$2"; shift 2;;
    --once)         ONCE=1; shift;;
    *) echo "WATCH ERROR unknown arg: $1"; exit 64;;
  esac
done
[ -z "$WORKSPACE" ] && { echo "WATCH ERROR --workspace is required"; exit 64; }
[ "$INTERVAL" -lt 1 ] && INTERVAL=1

# Throttle gh to roughly once per 60 seconds (rate limit)
GH_EVERY=$(( (60 + INTERVAL - 1) / INTERVAL ))
[ "$GH_EVERY" -lt 1 ] && GH_EVERY=1

state_dir=$(mktemp -d /tmp/herdr-event-watch.XXXXXX)
trap 'rm -rf "$state_dir"' EXIT
prev=""
herdr_fail=0
tick=0

snapshot_lanes() {
  herdr pane list --workspace "$WORKSPACE" 2>/dev/null | python3 -c '
import json,sys
prefix=sys.argv[1]
try:
    d=json.load(sys.stdin)
except Exception:
    sys.exit(1)
for p in d.get("result",{}).get("panes",[]):
    lbl=p.get("label") or ""
    st=p.get("agent_status") or "?"
    if not prefix or lbl.startswith(prefix):
        if lbl:
            print(lbl+"="+st)
' "$PREFIX" | sort
}

list_inbox() {
  # $1 = dir. If INBOX_PREFIX is set, filter by name prefix.
  ls -1 "$1" 2>/dev/null | { [ -n "$INBOX_PREFIX" ] && grep "^${INBOX_PREFIX}" || cat; } | sort
}

# Inbox baseline (existing files are NOT emitted — anything that arrived
# before the watch started must be swept manually).
i=0
for d in "${INBOX_DIRS[@]:-}"; do
  [ -z "$d" ] && continue
  list_inbox "$d" > "$state_dir/inbox.$i.seen"
  i=$((i+1))
done

while true; do
  # --- INBOX watch (primary: durable artifacts, every tick) ---
  i=0
  for d in "${INBOX_DIRS[@]:-}"; do
    [ -z "$d" ] && continue
    list_inbox "$d" > "$state_dir/inbox.$i.cur"
    if [ -s "$state_dir/inbox.$i.seen" ] || [ -s "$state_dir/inbox.$i.cur" ]; then
      comm -13 "$state_dir/inbox.$i.seen" "$state_dir/inbox.$i.cur" | while IFS= read -r f; do
        [ -n "$f" ] && echo "INBOX $f"
      done
    fi
    mv "$state_dir/inbox.$i.cur" "$state_dir/inbox.$i.seen"
    i=$((i+1))
  done

  # --- LANE watch (backstop: sampled) ---
  snap=$(snapshot_lanes)
  if [ -z "$snap" ]; then
    herdr_fail=$((herdr_fail+1))
    # Only emit a watch failure after 30 consecutive misses (~5 min at default interval)
    [ "$herdr_fail" -eq 30 ] && echo "WATCH ERROR herdr pane list returning empty for workspace $WORKSPACE"
  else
    herdr_fail=0
    if [ -n "$prev" ]; then
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        st="${line##*=}"
        if [ "$st" = "done" ] || [ "$st" = "blocked" ]; then
          echo "LANE $line"
        fi
      done < <(comm -13 <(echo "$prev") <(echo "$snap"))
    fi
    prev="$snap"
  fi

  # --- CI watch (roughly once per 60s) ---
  if [ -n "$REPO" ] && [ "${#PRS[@]}" -gt 0 ] && [ $((tick % GH_EVERY)) -eq 0 ]; then
    for pr in "${PRS[@]}"; do
      c=$(gh pr checks "$pr" --repo "$REPO" 2>/dev/null | awk -F'\t' -v ck="$CHECK" '$1==ck{print $2; exit}') || true
      [ -z "$c" ] && continue
      case "$c" in
        pass|success) result=pass;;
        fail|failure) result=fail;;
        *) continue;;
      esac
      # Dedup key is PR+result+head. Without head, a re-finalization on a new
      # head after update-branch would never be emitted (measured 2026-07-21 —
      # the LANE backstop saved it).
      head=$(gh pr view "$pr" --repo "$REPO" --json headRefOid --jq '.headRefOid[0:12]' 2>/dev/null) || head="nohead"
      key="pr${pr}-${result}-${head:-nohead}"
      if [ ! -e "$state_dir/$key" ]; then
        : > "$state_dir/$key"
        echo "CI PR#$pr $CHECK -> $result (head ${head:-?})"
      fi
    done
  fi

  [ "$ONCE" -eq 1 ] && exit 0
  tick=$((tick+1))
  sleep "$INTERVAL"
done
