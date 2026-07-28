#!/usr/bin/env bash
# Step 1 of open-source publish: back up the current Entaina/cream history
# to a private repo BEFORE any force-push.
#
# This script lives on branch main (not on open-source-fresh until after publish).
# Run from repo root:
#   git checkout main
#   ./script/backup-before-open-source.sh
#
# Manual equivalent:
#   git push git@github.com:Entaina/cream-internal.git main:main
set -euo pipefail

BACKUP_REMOTE="${BACKUP_REMOTE:-git@github.com:Entaina/cream-internal.git}"

if [[ "$(git branch --show-current)" != "main" ]]; then
  echo "Switch to main first: git checkout main"
  exit 1
fi

echo "=== Backup current Entaina/cream history ==="
echo ""
echo "Prerequisite (once, in GitHub):"
echo "  Create a PRIVATE empty repo: Entaina/cream-internal"
echo ""
read -r -p "Has cream-internal been created on GitHub? [y/N] " READY
if [[ "$READY" != "y" && "$READY" != "Y" ]]; then
  echo "Create https://github.com/Entaina/cream-internal first, then re-run."
  exit 0
fi

echo ""
echo "Pushing main (full history) to ${BACKUP_REMOTE} ..."
git push "${BACKUP_REMOTE}" main:main --force-with-lease

echo ""
echo "Optional: mirror all branches and tags"
read -r -p "Also push all branches/tags to cream-internal? [y/N] " MIRROR
if [[ "$MIRROR" == "y" || "$MIRROR" == "Y" ]]; then
  git push "${BACKUP_REMOTE}" --all --force-with-lease
  git push "${BACKUP_REMOTE}" --tags --force-with-lease || true
fi

echo ""
echo "Backup done. Verify on GitHub that cream-internal has the expected history."
echo "Next:"
echo "  git checkout open-source-fresh"
echo "  ./script/publish-open-source.sh"
