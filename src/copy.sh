#!/bin/bash
# copy.sh <field> <query>
# Wraps pw-copy.applescript: reports a clean message and optionally clears
# the clipboard after a delay.

FIELD="$1"
QUERY="$2"

DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$QUERY" ]; then
  echo "Type something to search for."
  exit 0
fi

OUT="$(/usr/bin/osascript "$DIR/pw-copy.applescript" "$FIELD" "$QUERY" 2>&1)"
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  # osascript errors look like: "pw-copy.applescript: execution error: <msg> (-2700)"
  MSG="${OUT##*execution error: }"
  MSG="${MSG%% (-*}"
  [ -z "$MSG" ] && MSG="$OUT"
  case "$MSG" in
    *"not allowed assistive access"*|*"osascript is not allowed"*|*1002*|*"-25211"*)
      MSG="Grant Accessibility permission to Alfred in System Settings › Privacy & Security › Accessibility."
      ;;
    *"Invalid index"*|*"-1719"*)
      # Passwords replaced its window mid-lookup, usually because it was
      # still launching or waiting to be unlocked.
      MSG="Passwords was still starting up. Unlock it and try again."
      ;;
  esac
  echo "$MSG"
  exit 0
fi

# Auto-clear the clipboard, but only if it still holds what we just copied.
# Compared by hash so the secret is never held in a shell variable.
SECS="${CLEAR_CLIPBOARD_AFTER:-45}"
if [ "$SECS" -gt 0 ] 2>/dev/null; then
  SIG="$(pbpaste | /usr/bin/shasum -a 256)"
  (
    sleep "$SECS"
    if [ "$(pbpaste | /usr/bin/shasum -a 256)" = "$SIG" ]; then
      printf '' | pbcopy
    fi
  ) >/dev/null 2>&1 &
  disown 2>/dev/null
  echo "$OUT (clipboard clears in ${SECS}s)"
else
  echo "$OUT"
fi
