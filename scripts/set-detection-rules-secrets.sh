#!/usr/bin/env bash
set -euo pipefail

# Reads cluster credentials and sets them as secrets in the detection-rules fork.
# Run this after the initial terraform-dac deployment completes.
#
# Usage: bash scripts/set-detection-rules-secrets.sh
# Or with explicit values:
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

REPO="stuartMoorhouse/detection-rules"

# If not provided via env, prompt the user to supply them
if [ -z "${DEV_KIBANA_URL:-}" ]; then
  echo "Could not auto-fetch cluster credentials. Please set these environment variables and re-run:"
  echo ""
  echo "  export DEV_KIBANA_URL=https://..."
  echo "  export DEV_KIBANA_USERNAME=elastic"
  echo "  export DEV_KIBANA_PASSWORD=..."
  echo "  export PROD_KIBANA_URL=https://..."
  echo "  export PROD_KIBANA_USERNAME=elastic"
  echo "  export PROD_KIBANA_PASSWORD=..."
  echo ""
  echo "You can find these values by running:"
  echo "  cd ../terraform-dac && terraform output"
  exit 1
fi

# Validate all required variables are present
for var in DEV_KIBANA_URL DEV_KIBANA_USERNAME DEV_KIBANA_PASSWORD \
           PROD_KIBANA_URL PROD_KIBANA_USERNAME PROD_KIBANA_PASSWORD; do
  if [ -z "${!var:-}" ]; then
    echo "Error: $var is not set." >&2
    exit 1
  fi
done

gh secret set DEV_KIBANA_URL      --repo "$REPO" --body "$DEV_KIBANA_URL"
gh secret set DEV_KIBANA_USERNAME --repo "$REPO" --body "$DEV_KIBANA_USERNAME"
gh secret set DEV_KIBANA_PASSWORD --repo "$REPO" --body "$DEV_KIBANA_PASSWORD"
gh secret set PROD_KIBANA_URL     --repo "$REPO" --body "$PROD_KIBANA_URL"
gh secret set PROD_KIBANA_USERNAME --repo "$REPO" --body "$PROD_KIBANA_USERNAME"
gh secret set PROD_KIBANA_PASSWORD --repo "$REPO" --body "$PROD_KIBANA_PASSWORD"

echo "Secrets set in $REPO"
echo "The detection-rules fork is now fully configured."
