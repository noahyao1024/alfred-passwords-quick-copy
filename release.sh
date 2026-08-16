#!/bin/bash
# Creates the GitHub repo if needed, pushes, and publishes a release with the
# workflow attached. Requires the gh CLI: brew install gh && gh auth login
set -e
cd "$(dirname "$0")"

: "${GH_USER:?Set GH_USER to your GitHub username}"
: "${AUTHOR:?Set AUTHOR to your name}"
REPO="${REPO:-alfred-passwords-quick-copy}"
VERSION="${VERSION:-0.3.0}"
NAME="Verification Codes"
DESCRIPTION="Alfred workflow to copy time-based verification codes, generated locally from seeds in your login keychain"

echo "Building $VERSION with GH_USER=$GH_USER AUTHOR=$AUTHOR"
# VERSION must be exported: build_plist.py reads it, and without it the bundle
# would claim a different version from the tag it ships under.
export GH_USER AUTHOR REPO VERSION
./build.sh

if [ ! -d .git ]; then
  git init -q
  git branch -M main
fi
git add -A
git diff --cached --quiet || git commit -q -m "Release $VERSION"

if ! git remote get-url origin >/dev/null 2>&1; then
  gh repo create "$REPO" --public --source=. --remote=origin \
    --description "$DESCRIPTION"
fi
git push -u origin main

gh release create "v$VERSION" "dist/$NAME.alfredworkflow" \
  --title "v$VERSION" \
  --notes "Copy a time-based verification code to your clipboard via Alfred.

Codes are generated locally from a seed held in your login keychain, so this
works offline, opens nothing, and needs no Accessibility permission.

Download the .alfredworkflow file below and double-click to install, then store
a seed with: python3 src/totp.py --store \"you@example.com\""

echo
echo "Done: https://github.com/$GH_USER/$REPO"
