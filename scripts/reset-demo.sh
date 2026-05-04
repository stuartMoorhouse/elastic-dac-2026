#!/usr/bin/env bash
set -euo pipefail

REPO="stuartMoorhouse/detection-rules"

echo "Resetting detection-rules fork to clean demo state..."

# Close open PRs
gh pr list --repo "$REPO" --state open --json number --jq '.[].number' | while read -r pr; do
  gh pr close "$pr" --repo "$REPO" --comment "Closed by reset-demo script"
  echo "Closed PR #$pr"
done

# Delete feature/fix branches
gh api "repos/$REPO/branches" --paginate --jq '.[].name' \
  | grep -E '^(feature|feat|fix)/' \
  | while read -r branch; do
    gh api -X DELETE "repos/$REPO/git/refs/heads/$branch" 2>/dev/null || true
    echo "Deleted branch: $branch"
  done

echo "Reset complete."
