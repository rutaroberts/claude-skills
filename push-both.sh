#!/bin/bash
# Push current branch to both Yahoo and personal GitHub accounts.
# Usage: ./push-both.sh [branch]   (defaults to current branch)

BRANCH="${1:-$(git rev-parse --abbrev-ref HEAD)}"

echo "→ Pushing '$BRANCH' to Yahoo (rroberts01_yahoo)..."
gh auth switch --user rroberts01_yahoo 2>/dev/null
if git push origin "$BRANCH"; then
  echo "✓ Yahoo push complete"
else
  echo "✗ Yahoo push failed (check auth)"
fi

echo ""
echo "→ Pushing '$BRANCH' to personal (rutaroberts)..."
gh auth switch --user rutaroberts 2>/dev/null
if git push personal "$BRANCH"; then
  echo "✓ Personal push complete"
else
  echo "✗ Personal push failed (check auth)"
fi

# Leave personal as the active account (safer default)
gh auth switch --user rutaroberts 2>/dev/null
