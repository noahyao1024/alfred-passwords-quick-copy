#!/bin/bash
# add-otp.sh [account]
# Stores the seed currently on the clipboard. The name is optional: an
# otpauth:// link already carries one.
#
# The seed arrives by clipboard rather than as a keyword argument on purpose.
# Alfred keeps a history of what you type into it, and a TOTP seed is not
# something to leave sitting in a searchable log.

ACCOUNT="$1"
DIR="$(cd "$(dirname "$0")" && pwd)"

CLIP="$(pbpaste)"
if [ -z "$CLIP" ]; then
  echo "Clipboard is empty. Copy the secret or otpauth:// link first."
  exit 0
fi

if [ -n "$ACCOUNT" ]; then
  OUT="$(printf '%s' "$CLIP" | /usr/bin/python3 "$DIR/totp.py" --store "$ACCOUNT" 2>&1)"
else
  OUT="$(printf '%s' "$CLIP" | /usr/bin/python3 "$DIR/totp.py" --store 2>&1)"
fi
STATUS=$?

if [ "$STATUS" -ne 0 ]; then
  echo "$OUT"
  exit 0
fi

# The clipboard was holding a seed. Do not leave it there.
printf '' | pbcopy

echo "$OUT"
