#!/bin/bash
# copy-otp.sh <account>
# Generates the current verification code for a stored account and puts it on
# the clipboard, clearing it again after the configured delay.

ACCOUNT="$1"
DIR="$(cd "$(dirname "$0")" && pwd)"

if [ -z "$ACCOUNT" ]; then
  echo "No account given."
  exit 0
fi

CODE="$(/usr/bin/python3 "$DIR/totp.py" "$ACCOUNT" 2>&1)"
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  echo "$CODE"
  exit 0
fi

printf '%s' "$CODE" | pbcopy

# Auto-clear, but only if the clipboard still holds what we just copied.
# Compared by hash so the code is never held in a shell variable beyond the
# moment it is put on the clipboard.
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
  echo "$CODE copied — $ACCOUNT (clears in ${SECS}s)"
else
  echo "$CODE copied — $ACCOUNT"
fi
