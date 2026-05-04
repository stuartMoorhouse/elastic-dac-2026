#!/usr/bin/env bash
set -euo pipefail

# Sets cluster credentials as GitHub Secrets in both demo repos:
#   stuartMoorhouse/detection-rules  (Python CLI workflows)
#   stuartMoorhouse/terraform-dac    (Terraform rule deployment workflows)
#
# Run this after `terraform apply` in infra/ completes.
#
# Usage:
#   bash scripts/set-detection-rules-secrets.sh
#
# Or supply values via environment to skip prompts:
#   DEV_KIBANA_URL=https://... DEV_KIBANA_USERNAME=elastic DEV_KIBANA_PASSWORD=... \
#   PROD_KIBANA_URL=https://... PROD_KIBANA_USERNAME=elastic PROD_KIBANA_PASSWORD=... \
#   bash scripts/set-detection-rules-secrets.sh

check_deps() {
  for cmd in gh jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: $cmd required" >&2
      exit 1
    fi
  done
}

check_deps

DETECTION_RULES_REPO="stuartMoorhouse/detection-rules"
TERRAFORM_DAC_REPO="stuartMoorhouse/terraform-dac"

if [ -z "${DEV_KIBANA_URL:-}" ]; then
  echo "Cluster credentials not found in environment. Set these and re-run:"
  echo ""
  echo "  export DEV_KIBANA_URL=https://..."
  echo "  export DEV_KIBANA_USERNAME=elastic"
  echo "  export DEV_KIBANA_PASSWORD=..."
  echo "  export PROD_KIBANA_URL=https://..."
  echo "  export PROD_KIBANA_USERNAME=elastic"
  echo "  export PROD_KIBANA_PASSWORD=..."
  echo ""
  echo "Find these values by running: cd infra && terraform output -json | jq"
  exit 1
fi

for var in DEV_KIBANA_URL DEV_KIBANA_USERNAME DEV_KIBANA_PASSWORD \
           PROD_KIBANA_URL PROD_KIBANA_USERNAME PROD_KIBANA_PASSWORD; do
  if [ -z "${!var:-}" ]; then
    echo "Error: $var is not set." >&2
    exit 1
  fi
done

echo "=== Setting secrets in $DETECTION_RULES_REPO ==="
gh secret set DEV_KIBANA_URL       --repo "$DETECTION_RULES_REPO" --body "$DEV_KIBANA_URL"
gh secret set DEV_KIBANA_USERNAME  --repo "$DETECTION_RULES_REPO" --body "$DEV_KIBANA_USERNAME"
gh secret set DEV_KIBANA_PASSWORD  --repo "$DETECTION_RULES_REPO" --body "$DEV_KIBANA_PASSWORD"
gh secret set PROD_KIBANA_URL      --repo "$DETECTION_RULES_REPO" --body "$PROD_KIBANA_URL"
gh secret set PROD_KIBANA_USERNAME --repo "$DETECTION_RULES_REPO" --body "$PROD_KIBANA_USERNAME"
gh secret set PROD_KIBANA_PASSWORD --repo "$DETECTION_RULES_REPO" --body "$PROD_KIBANA_PASSWORD"
echo "Done."

echo ""
echo "=== Setting secrets in $TERRAFORM_DAC_REPO ==="
# deploy-dev.yml uses DEV_KIBANA_URL / DEV_KIBANA_PASSWORD
# deploy-main.yml uses PROD_KIBANA_URL / PROD_KIBANA_PASSWORD
gh secret set DEV_KIBANA_URL       --repo "$TERRAFORM_DAC_REPO" --body "$DEV_KIBANA_URL"
gh secret set DEV_KIBANA_PASSWORD  --repo "$TERRAFORM_DAC_REPO" --body "$DEV_KIBANA_PASSWORD"
gh secret set PROD_KIBANA_URL      --repo "$TERRAFORM_DAC_REPO" --body "$PROD_KIBANA_URL"
gh secret set PROD_KIBANA_PASSWORD --repo "$TERRAFORM_DAC_REPO" --body "$PROD_KIBANA_PASSWORD"
echo "Done."

echo ""
echo "Both repos are now fully configured."
