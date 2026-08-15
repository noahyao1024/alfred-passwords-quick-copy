#!/bin/bash
# Builds dist/Passwords Quick Copy.alfredworkflow from src/
set -e
cd "$(dirname "$0")"
NAME="Passwords Quick Copy"

# Syntax-check the AppleScripts. osascript only compiles at run time, so
# without this a script can ship broken and only fail on a user's machine.
for f in src/*.applescript; do
  osacompile -o /dev/null "$f" || { echo "FAILED to compile: $f" >&2; exit 1; }
done
echo "AppleScripts compile OK"

python3 build_plist.py
mkdir -p dist
rm -f "dist/$NAME.alfredworkflow"
chmod +x src/copy.sh src/pw-copy.applescript src/pw-dump.applescript
( cd src && zip -q -r "../dist/$NAME.alfredworkflow" . -x '.*' )
echo "Built dist/$NAME.alfredworkflow"
