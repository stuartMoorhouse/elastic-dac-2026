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
echo "Current branch: $BRANCH"
echo ""
echo "This promotes the rules on the current branch to the Prod cluster."
echo "Run this after merging your feature branch to dev."
echo ""

read -r -p "Promote rules to PRODUCTION? (yes/no): " answer
if [[ "$answer" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

echo "Validating detection rules..."
bash scripts/validate-rules.sh || { echo "Aborting: rule validation failed." >&2; exit 1; }

echo "Promoting rules to Prod environment..."
terraform -chdir=terraform apply -var="environment=prod"

bash scripts/get-env.sh

prod_kibana=$(jq -r '.prod_kibana_endpoint.value' shared/env.json)
echo ""
echo "Prod Kibana: $prod_kibana"
echo "Rules promoted to Prod."
