#!/usr/bin/env bash
set -euo pipefail

# Build and deploy GitHub Pages content from web/ into docs/.
#
# Usage:
#   ./deploy_pages.sh [memory_bytes] [title] [commit_message]
#
# Example:
#   ./deploy_pages.sh 200000000 voyage "Update Pages build"

MEMORY="${1:-200000000}"
TITLE="${2:-voyage}"
COMMIT_MESSAGE="${3:-Update Pages build}"

./build_web.sh "$MEMORY" "$TITLE"

rm -rf docs
mkdir -p docs
cp -R web/* docs/
touch docs/.nojekyll

git add docs

if git diff --cached --quiet; then
  echo "No docs changes to commit."
  exit 0
fi

git commit -m "$COMMIT_MESSAGE"
git push

echo "Deployed docs/ for GitHub Pages."
