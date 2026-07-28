#!/usr/bin/env bash
# Step 2 of open-source publish: force-push sanitized history to Entaina/cream.
#
# Prerequisites (in order):
#   1. ./script/backup-before-open-source.sh   (cream-internal must exist)
#   2. DEPLOY_PATH set in GitHub → Environments → production → Variables
#      e.g. DEPLOY_PATH=/home/deploy/cream
#
# Production secrets (SSH_*, GHCR_*) stay on Entaina/cream — no changes needed.
set -euo pipefail

echo "=== Pre-flight: sensitive strings (should be empty except deliberate keeps) ==="
if rg -i 'entaina\.ai|josemi|agust|194\.164|0ANqRpG|ES56 0182|cream-demo\.local|demonodojo|agustincnc' \
  --glob '!LICENSE' --glob '!script/publish-open-source.sh' --glob '!script/backup-before-open-source.sh'; then
  echo "Abort: sensitive references found."
  exit 1
fi

echo ""
echo "=== Prerequisites ==="
echo "  [1] cream-internal backup pushed"
echo "      git checkout main && ./script/backup-before-open-source.sh"
echo "      (backup script is on main only — run before switching to open-source-fresh)"
echo "  [2] DEPLOY_PATH variable in production environment (e.g. /home/deploy/cream)"
echo ""
read -r -p "Backup to cream-internal is done? [y/N] " BACKUP_OK
if [[ "$BACKUP_OK" != "y" && "$BACKUP_OK" != "Y" ]]; then
  echo "Run from main first:"
  echo "  git checkout main && ./script/backup-before-open-source.sh"
  exit 0
fi

read -r -p "DEPLOY_PATH is set in GitHub production environment? [y/N] " DEPLOY_OK
if [[ "$DEPLOY_OK" != "y" && "$DEPLOY_OK" != "Y" ]]; then
  echo "Set DEPLOY_PATH in GitHub → Settings → Environments → production → Variables"
  exit 0
fi

CURRENT_BRANCH="$(git branch --show-current)"
if [[ "$CURRENT_BRANCH" != "open-source-fresh" ]]; then
  echo "Checking out open-source-fresh..."
  git checkout open-source-fresh
fi

COMMITS="$(git rev-list --count HEAD)"
if [[ "$COMMITS" != "1" ]]; then
  echo "Abort: expected exactly 1 commit on open-source-fresh, found $COMMITS"
  exit 1
fi

echo ""
echo "=== Force-push sanitized history to Entaina/cream main ==="
echo "This replaces main on Entaina/cream with a single clean commit."
echo "The full history remains in Entaina/cream-internal (private)."
echo ""
read -r -p "Continue? [y/N] " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

git push -u origin open-source-fresh:main --force

echo ""
echo "Done."
echo "  - Verify GitHub main shows 1 commit"
echo "  - Make Entaina/cream public if desired"
echo "  - GHCR package ghcr.io/entaina/cream stays linked to this repo"
