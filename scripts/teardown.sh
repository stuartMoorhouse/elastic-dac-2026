#!/usr/bin/env bash
set -euo pipefail

echo "This will:"
echo "  1. Delete the stuartMoorhouse/detection-rules fork"
echo "  2. Delete the stuartMoorhouse/terraform-dac repo"
echo "  3. Note: Elastic Cloud clusters must be destroyed separately via terraform destroy in terraform-dac"
echo ""
read -r -p "Proceed with teardown? (yes/no): " answer
[ "$answer" = "yes" ] || { echo "Aborted."; exit 0; }

gh repo delete stuartMoorhouse/detection-rules --yes 2>/dev/null \
  || echo "detection-rules fork not found, skipping"

gh repo delete stuartMoorhouse/terraform-dac --yes 2>/dev/null \
  || echo "terraform-dac not found, skipping"

echo "Repos deleted."
echo ""
echo "To destroy Elastic Cloud clusters, run terraform destroy in the terraform-dac directory"
echo "before deleting the repo, or contact Elastic Cloud support."
