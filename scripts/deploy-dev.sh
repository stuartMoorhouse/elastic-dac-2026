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

BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
echo "Branch: $BRANCH"
echo ""

echo "Validating detection rules..."
bash scripts/validate-rules.sh || { echo "Aborting: rule validation failed." >&2; exit 1; }

echo "Deploying rules to Dev environment..."
terraform -chdir=terraform apply -var="environment=dev"

bash scripts/get-env.sh

dev_kibana=$(jq -r '.dev_kibana_endpoint.value' shared/env.json)
echo ""
echo "Dev Kibana: $dev_kibana"
echo ""
echo "Next steps:"
echo "  1. Validate rules in Dev Kibana"
echo "  2. Commit your TOML files: git add detection-rules/custom-rules/ && git commit"
echo "  3. Open a PR targeting the dev branch"
echo "  4. After merge, run: bash scripts/deploy-prod.sh"
