#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INFRA_DIR="$REPO_DIR/infra"

GITHUB_USER=$(gh api user --jq '.login')

# ---------------------------------------------------------------------------
# Helper: delete all custom (non-prebuilt) rules from a Kibana cluster
# ---------------------------------------------------------------------------
delete_custom_rules() {
  local label="$1" kibana="$2" user="$3" password="$4"

  if [[ -z "$kibana" || -z "$password" ]]; then
    echo "  $label: skipped (no credentials)"
    return 0
  fi

  local ids
  ids="$(curl -sS -u "$user:$password" \
    "$kibana/api/detection_engine/rules/_find?per_page=10000&filter=alert.attributes.params.immutable:false" \
    -H 'Content-Type: application/json' \
    | python3 -c 'import json,sys; d=json.load(sys.stdin); print(" ".join(r["id"] for r in d.get("data",[])))' 2>/dev/null || true)"

  if [[ -z "$ids" ]]; then
    echo "  $label: no custom rules"
    return 0
  fi

  local payload
  payload="$(python3 -c 'import json,sys; print(json.dumps({"action":"delete","ids":sys.argv[1].split()}))' "$ids")"

  curl -sS -u "$user:$password" \
    -X POST "$kibana/api/detection_engine/rules/_bulk_action" \
    -H 'kbn-xsrf: true' -H 'Content-Type: application/json' \
    -d "$payload" >/dev/null

  local count
  count="$(echo "$ids" | wc -w | tr -d ' ')"
  echo "  $label: deleted $count custom rule(s)"
}

reset_repo() {
  local repo="$GITHUB_USER/$1"
  echo "=== Resetting $repo ==="

  gh pr list --repo "$repo" --state open --json number --jq '.[].number' | while read -r pr; do
    gh pr close "$pr" --repo "$repo" --comment "Closed by reset-demo script"
    echo "  Closed PR #$pr"
  done

  branches=$(gh api "repos/$repo/branches" --paginate --jq '.[].name' \
    | grep -E '^(feature|feat|fix|chore)/' || true)
  for branch in $branches; do
    gh api -X DELETE "repos/$repo/git/refs/heads/$branch" 2>/dev/null || true
    echo "  Deleted remote branch: $branch"
  done

  echo "  Done"
}

reset_repo "detection-rules"

# Clean up local branches in the detection-rules clone
CLONE_DIR="$REPO_DIR/../detection-rules"
if [[ -d "$CLONE_DIR/.git" ]]; then
  echo ""
  echo "=== Cleaning local detection-rules clone ==="
  git -C "$CLONE_DIR" checkout main --quiet
  local_branches=$(git -C "$CLONE_DIR" branch --format='%(refname:short)' \
    | grep -E '^(feature|feat|fix|chore)/' || true)
  for branch in $local_branches; do
    git -C "$CLONE_DIR" branch -D "$branch"
    echo "  Deleted local branch: $branch"
  done
  echo "  Done"
fi

# ---------------------------------------------------------------------------
# Delete custom rules from Dev and Prod Kibana clusters
# ---------------------------------------------------------------------------
echo ""
echo "=== Deleting custom rules from Kibana clusters ==="
tf_out() { terraform -chdir="$INFRA_DIR" output -raw "$1" 2>/dev/null || true; }
delete_custom_rules "dev " "$(tf_out dev_kibana_endpoint)"  "$(tf_out dev_elasticsearch_username)"  "$(tf_out dev_elasticsearch_password)"
delete_custom_rules "prod" "$(tf_out prod_kibana_endpoint)" "$(tf_out prod_elasticsearch_username)" "$(tf_out prod_elasticsearch_password)"

# Clear exported rules from Scenario 1 so the directory is empty for the next run
CUSTOM_RULES_DIR="$REPO_DIR/../detection-rules/custom-rules/rules"
if [[ -d "$CUSTOM_RULES_DIR" ]]; then
  echo ""
  echo "=== Clearing exported rules (detection-rules/custom-rules/rules/) ==="
  find "$CUSTOM_RULES_DIR" -name "*.toml" -print -delete
  echo "  Done"
fi

# ---------------------------------------------------------------------------
# Scenario 2: destroy deployed resources so terraform plan shows a diff next run
# ---------------------------------------------------------------------------
echo ""
echo "=== Resetting Scenario 2 (Terraform HCL) ==="
terraform -chdir="$REPO_DIR/terraform/scenario2" destroy -auto-approve
echo "  Done"

# ---------------------------------------------------------------------------
# Scenario 3: remove any TOML files added during the demo, then destroy so
# the clusters start clean and terraform apply during the demo creates the rules
# ---------------------------------------------------------------------------
echo ""
echo "=== Resetting Scenario 3 (TOML + for_each) ==="
find "$REPO_DIR/local-detection-rules" -name "*.toml" \
  ! -name "powershell_encoded_command.toml" \
  ! -name "lateral_movement_psexec.toml" \
  ! -name "c2_beacon_dns.toml" \
  -print -delete
terraform -chdir="$REPO_DIR/terraform/scenario3" destroy -auto-approve
echo "  Done"

# ---------------------------------------------------------------------------
# Reload test data so Dev cluster is fresh for the next run
# ---------------------------------------------------------------------------
echo ""
bash "$SCRIPT_DIR/load-test-data.sh"

echo ""
echo "Reset complete."
