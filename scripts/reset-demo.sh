#!/usr/bin/env bash
set -euo pipefail

GITHUB_USER=$(gh api user --jq '.login')

reset_repo() {
  local repo="$GITHUB_USER/$1"
  echo "=== Resetting $repo ==="

  gh pr list --repo "$repo" --state open --json number --jq '.[].number' | while read -r pr; do
    gh pr close "$pr" --repo "$repo" --comment "Closed by reset-demo script"
    echo "  Closed PR #$pr"
  done

  gh api "repos/$repo/branches" --paginate --jq '.[].name' \
    | grep -E '^(feature|feat|fix)/' \
    | while read -r branch; do
        gh api -X DELETE "repos/$repo/git/refs/heads/$branch" 2>/dev/null || true
        echo "  Deleted branch: $branch"
      done

  echo "  Done"
}

reset_repo "detection-rules"

# Reload test data so Dev cluster is fresh for the next run
echo ""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/load-test-data.sh"

echo ""
echo "Reset complete."
