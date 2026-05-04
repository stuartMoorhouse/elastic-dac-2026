#!/usr/bin/env bash
set -euo pipefail

echo "This will:"
echo "  1. Run terraform destroy in infra/ — deletes terraform-dac repo,"
echo "     branch protection, secrets, and Elastic Cloud clusters"
echo "  2. Delete the stuartMoorhouse/detection-rules fork"
echo ""
read -r -p "Proceed with teardown? (yes/no): " answer
[ "$answer" = "yes" ] || { echo "Aborted."; exit 0; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../infra"

if [ -f "$INFRA_DIR/terraform.tfstate" ]; then
  echo "Running terraform destroy in infra/..."
  export GITHUB_TOKEN="${GITHUB_TOKEN:-$(gh auth token)}"
  terraform -chdir="$INFRA_DIR" destroy -auto-approve
else
  echo "No terraform state found in infra/ — skipping terraform destroy."
  echo "Deleting terraform-dac repo via gh CLI..."
  gh repo delete stuartMoorhouse/terraform-dac --yes 2>/dev/null \
    || echo "terraform-dac not found, skipping"
fi

echo ""
echo "Deleting detection-rules fork..."
gh repo delete stuartMoorhouse/detection-rules --yes 2>/dev/null \
  || echo "detection-rules fork not found, skipping"

echo ""
echo "Teardown complete."
