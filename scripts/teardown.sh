#!/usr/bin/env bash
set -euo pipefail

GITHUB_USER=$(gh api user --jq '.login')

echo "This will:"
echo "  1. Run terraform destroy in infra/ — deletes branch protection,"
echo "     secrets, and Elastic Cloud clusters"
echo "  2. Delete the $GITHUB_USER/detection-rules fork"
echo ""
read -r -p "Proceed with teardown? (yes/no): " answer
[ "$answer" = "yes" ] || { echo "Aborted."; exit 0; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra"

if [ -f "$INFRA_DIR/terraform.tfstate" ]; then
  echo "Running terraform destroy in infra/..."
  export GITHUB_TOKEN="${GITHUB_TOKEN:-$(gh auth token)}"
  export TF_VAR_ec_api_key="${TF_VAR_ec_api_key:-${EC_API_KEY:-}}"
  export TF_VAR_detection_team_lead_token="${TF_VAR_detection_team_lead_token:-${DETECTION_TEAM_LEAD_TOKEN:-}}"
  if [ -z "${TF_VAR_ec_api_key:-}" ]; then
    echo "Error: EC_API_KEY is not set." >&2; exit 1
  fi
  if [ -z "${TF_VAR_detection_team_lead_token:-}" ]; then
    echo "Error: DETECTION_TEAM_LEAD_TOKEN is not set." >&2; exit 1
  fi
  terraform -chdir="$INFRA_DIR" destroy -auto-approve
else
  echo "No terraform state found in infra/ — skipping terraform destroy."
fi

echo ""
echo "Deleting detection-rules fork..."
gh repo delete "$GITHUB_USER/detection-rules" --yes 2>/dev/null \
  || echo "detection-rules fork not found, skipping"

echo ""
echo "Teardown complete."
