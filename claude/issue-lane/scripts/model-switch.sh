#!/usr/bin/env bash
# model-switch.sh — safely switch the model/effort of a codex TUI pane via herdr.
#
# Usage: model-switch.sh <pane_id> <model> [effort]
#   e.g. model-switch.sh w12:pP gpt-5.6-terra Medium
#
# Discipline (born from a real misfire where blind number-pressing selected a
# legacy model, because picker menus can differ per pane):
#   - NEVER press menu numbers blindly. Read the actual picker menu, derive
#     the number from the line that exactly matches the target model name.
#   - If the target is not in the menu, close the picker with Esc and exit 2
#     (never pick "the closest thing").
#   - Verify the pane footer afterwards. On mismatch, exit 2 — never claim
#     success that was not measured.
#
# exit: 0 = switched + footer verified / 2 = fail-closed abort (picker closed
#       via Esc) / 64 = usage error
set -u

PANE="${1:-}"; MODEL="${2:-}"; EFFORT="${3:-Medium}"
[ -z "$PANE" ] || [ -z "$MODEL" ] && { echo "usage: model-switch.sh <pane_id> <model> [effort]" >&2; exit 64; }
WS="${PANE%%:*}"

read_visible() { herdr pane read "$PANE" --source visible --lines "${1:-25}" --format text 2>/dev/null; }

abort() { # close the picker if open, then fail closed
  herdr pane send-keys "$PANE" Escape >/dev/null 2>&1; sleep 1
  herdr pane send-keys "$PANE" Escape >/dev/null 2>&1
  echo "model-switch: ABORT($PANE): $1" >&2
  exit 2
}

# Derive the option number whose label exactly matches the target.
# Option line format: "› 2. gpt-5.6-terra (current)  description..." / "  3. High  description..."
pick_number() { # $1=menu text, $2=target label
  echo "$1" | grep -E "^[› ]*[0-9]+\. +$2([ (]|$)" | head -1 | sed -E 's/^[› ]*([0-9]+)\..*/\1/'
}

# 1) The pane must be interactable (switching while working gets queued and misfires)
STATUS=$(herdr pane list --workspace "$WS" 2>/dev/null | jq -r --arg p "$PANE" \
  '.result.panes[] | select(.pane_id == $p) | .agent_status')
[ -z "$STATUS" ] && abort "pane not found"
case "$STATUS" in idle|done) ;; *) abort "agent_status=$STATUS (switching while working is forbidden)";; esac

# 2) Open the picker
herdr pane send-text "$PANE" '/model' || abort "send-text failed"
sleep 1.5; herdr pane send-keys "$PANE" Enter; sleep 3

MENU=$(read_visible 25)
echo "$MENU" | grep -q 'Select Model' || echo "$MENU" | grep -qE '^[› ]*1\. ' \
  || abort "model picker did not open (possibly leftover composer text)"

# 3) Model page: read menu -> derive number -> send
NUM=$(pick_number "$MENU" "$MODEL")
[ -z "$NUM" ] && abort "$MODEL not present in menu ($(echo "$MENU" | grep -cE '^[› ]*[0-9]+\.') options listed)"
for d in $(echo "$NUM" | grep -o .); do herdr pane send-keys "$PANE" "$d"; done
sleep 2.5

# 4) Effort page (some models skip it — then go straight to verification)
MENU2=$(read_visible 15)
if echo "$MENU2" | grep -qE '^[› ]*[0-9]+\. +(Low|Medium|High)'; then
  ENUM=$(pick_number "$MENU2" "$EFFORT")
  [ -z "$ENUM" ] && abort "$EFFORT not present in effort menu"
  for d in $(echo "$ENUM" | grep -o .); do herdr pane send-keys "$PANE" "$d"; done
  sleep 1; herdr pane send-keys "$PANE" Enter
fi
sleep 4

# 5) Footer verification (a mismatch is never reported as success)
EXPECT="$MODEL $(echo "$EFFORT" | tr '[:upper:]' '[:lower:]')"
FOOTER=$(read_visible 3 | grep -oE 'gpt-[0-9a-z.\-]+ [a-z]+' | tail -1)
if [ "$FOOTER" = "$EXPECT" ]; then
  echo "model-switch: OK $PANE -> $FOOTER"
  exit 0
fi
abort "footer mismatch: expected='$EXPECT' actual='${FOOTER:-<none>}' — inspect manually"
