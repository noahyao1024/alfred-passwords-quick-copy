#!/bin/bash
# Creates the GitHub repo, pushes, and publishes a release with the workflow
# attached. Requires the gh CLI: brew install gh && gh auth login
set -e
cd "$(dirname "$0")"

: "${GH_USER:?Set GH_USER to your GitHub username}"
: "${AUTHOR:?Set AUTHOR to your name}"
REPO="${REPO:-alfred-passwords-quick-copy}"
VERSION="${VERSION:-1.0.0}"
NAME="Passwords Quick Copy"

echo "Building with GH_USER=$GH_USER AUTHOR=$AUTHOR"
export GH_USER AUTHOR REPO
./build.sh

if [ ! -d .git ]; then
  git init -q
  git branch -M main
fi
git add -A
git diff --cached --quiet || git commit -q -m "Release $VERSION"

if ! git remote get-url origin >/dev/null 2>&1; then
  gh repo create "$REPO" --public --source=. --remote=origin \
    --description "Alfred workflow to copy passwords, usernames and verification codes from the Apple Passwords app"
fi
git push -u origin main

gh release create "v$VERSION" "dist/$NAME.alfredworkflow" \
  --title "v$VERSION" \
  --notes "Copy a password, username, verification code or website from the Apple Passwords app via Alfred.

Download the .alfredworkflow file below and double-click to install, then grant Alfred Accessibility permission."

echo
echo "Done: https://github.com/$GH_USER/$REPO"
