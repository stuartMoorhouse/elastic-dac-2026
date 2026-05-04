#!/usr/bin/env bash
set -euo pipefail

check_deps() {
  for cmd in terraform jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: $cmd is required but not installed." >&2
      exit 1
    fi
  done
}

check_deps

echo "This will re-apply all detection rules to the Dev environment."
echo "Terraform is idempotent — existing rules will be reconciled to the desired state."
echo ""
read -r -p "Continue? (yes/no): " answer
if [[ "$answer" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

echo "Resetting Dev environment..."
terraform -chdir=terraform apply -var="environment=dev"

bash scripts/get-env.sh

dev_kibana=$(jq -r '.dev_kibana_endpoint.value' shared/env.json)
echo "Dev Kibana: $dev_kibana"
echo "Demo reset complete."
