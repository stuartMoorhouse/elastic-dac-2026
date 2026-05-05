#!/usr/bin/env bash
set -euo pipefail

# Full demo setup: fork detection-rules, provision infrastructure via Terraform,
# then clone both demo repos ready for presentation.
#
# Prerequisites:
#   gh          authenticated (gh auth login)
#   git         installed
#   terraform   installed (>= 1.8)
#   EC_API_KEY  Elastic Cloud API key in environment
#
# Usage: bash scripts/setup.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$(cd "$SCRIPT_DIR/../templates" 2>/dev/null && pwd)" || true

# ---------------------------------------------------------------------------
# Prerequisites
# ---------------------------------------------------------------------------

check_deps() {
  local missing=()
  for cmd in gh git terraform; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "Error: missing required tools: ${missing[*]}" >&2
    echo "  gh          https://cli.github.com" >&2
    echo "  git         https://git-scm.com" >&2
    echo "  terraform   https://developer.hashicorp.com/terraform/install" >&2
    exit 1
  fi
}

check_deps

if ! gh auth status &>/dev/null; then
  echo "Error: gh is not authenticated. Run: gh auth login" >&2
  exit 1
fi

if [ -z "${EC_API_KEY:-}" ]; then
  echo "Error: EC_API_KEY is not set. Export your Elastic Cloud API key:" >&2
  echo "  export EC_API_KEY=<your-api-key>" >&2
  exit 1
fi

if [ -z "${DETECTION_TEAM_LEAD_TOKEN:-}" ]; then
  echo "Error: DETECTION_TEAM_LEAD_TOKEN is not set. Export a PAT for the detection-team-lead account:" >&2
  echo "  export DETECTION_TEAM_LEAD_TOKEN=<github-pat>" >&2
  exit 1
fi

if [ -z "$TEMPLATES_DIR" ] || [ ! -d "$TEMPLATES_DIR" ]; then
  echo "Error: templates directory not found at $SCRIPT_DIR/../templates" >&2
  exit 1
fi

GITHUB_USER=$(gh api user --jq '.login')
DEMO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Prerequisites OK."
echo "  GitHub user: $GITHUB_USER"
echo "  Demo repos will be cloned to: $DEMO_DIR"
echo ""

# ---------------------------------------------------------------------------
# Fork and configure detection-rules (Repo 1)
# ---------------------------------------------------------------------------

echo "=== Forking elastic/detection-rules ==="

if gh api "repos/$GITHUB_USER/detection-rules" &>/dev/null; then
  echo "Fork already exists — skipping"
else
  gh repo fork elastic/detection-rules --clone=false
  echo "Waiting 5s for fork to be ready..."
  sleep 5
fi

# Remove any existing branch protections so direct pushes and branch deletes succeed.
# Terraform will re-apply the correct protections during apply.
echo "Removing existing branch protections (if any)..."
for branch in main dev; do
  gh api -X DELETE "repos/$GITHUB_USER/detection-rules/branches/$branch/protection" \
    2>/dev/null && echo "  Removed protection on $branch" || true
done

# Delete all branches except main (elastic/detection-rules has hundreds)
echo "Cleaning up inherited branches (fetching branch list, may be slow)..."
BRANCHES=$(gh api "repos/$GITHUB_USER/detection-rules/branches" --paginate --jq '.[].name' 2>/dev/null | grep -v '^main$' || true)
BRANCH_COUNT=$(echo "$BRANCHES" | grep -c . 2>/dev/null || true)
if [ "${BRANCH_COUNT:-0}" -gt 0 ]; then
  echo "  Found $BRANCH_COUNT branches to delete (this may take a minute)..."
  i=0
  for branch in $BRANCHES; do
    i=$((i + 1))
    if [ $((i % 10)) -eq 1 ] || [ "$i" -eq "$BRANCH_COUNT" ]; then
      echo "  [$i/$BRANCH_COUNT] Deleting: $branch"
    fi
    gh api -X DELETE "repos/$GITHUB_USER/detection-rules/git/refs/heads/$branch" 2>/dev/null || true
  done
else
  echo "  No inherited branches to clean up"
fi
echo "Branch cleanup complete"

# Minimal fork settings
gh api -X PATCH "repos/$GITHUB_USER/detection-rules" \
  -f has_issues=true \
  -f has_projects=false \
  -f has_wiki=false \
  --silent
echo "Configured fork settings"

# Remove inherited upstream workflows (skip our own DaC demo workflows)
echo "Removing inherited workflows..."
OUR_WORKFLOWS=$(ls "$TEMPLATES_DIR/detection-rules-workflows"/*.yml 2>/dev/null | xargs -I{} basename {} | sort | tr '\n' ' ')
WORKFLOW_FILES=$(gh api "repos/$GITHUB_USER/detection-rules/contents/.github/workflows" --jq '.[].name' 2>/dev/null || true)
for wf in $WORKFLOW_FILES; do
  if echo " $OUR_WORKFLOWS " | grep -q " $wf "; then
    continue
  fi
  echo "  Removing inherited workflow: $wf"
  SHA=$(gh api "repos/$GITHUB_USER/detection-rules/contents/.github/workflows/$wf" --jq '.sha' 2>/dev/null || true)
  if [ -n "$SHA" ]; then
    gh api -X DELETE "repos/$GITHUB_USER/detection-rules/contents/.github/workflows/$wf" \
      -f message="Remove inherited workflow: $wf" \
      -f sha="$SHA" \
      --silent 2>/dev/null || true
  fi
done
echo "Inherited workflows removed"

# Push DaC demo workflows
WORKFLOWS_DIR="$TEMPLATES_DIR/detection-rules-workflows"
if [ -d "$WORKFLOWS_DIR" ]; then
  for wf_file in "$WORKFLOWS_DIR"/*.yml; do
    [ -f "$wf_file" ] || continue
    wf_name=$(basename "$wf_file")
    wf_content=$(base64 < "$wf_file")
    EXISTING_SHA=$(gh api "repos/$GITHUB_USER/detection-rules/contents/.github/workflows/$wf_name" --jq '.sha' 2>/dev/null || true)
    if [ -n "$EXISTING_SHA" ]; then
      gh api -X PUT "repos/$GITHUB_USER/detection-rules/contents/.github/workflows/$wf_name" \
        -f message="Add DaC demo workflow: $wf_name" \
        -f content="$wf_content" \
        -f sha="$EXISTING_SHA" \
        --silent
    else
      gh api -X PUT "repos/$GITHUB_USER/detection-rules/contents/.github/workflows/$wf_name" \
        -f message="Add DaC demo workflow: $wf_name" \
        -f content="$wf_content" \
        --silent
    fi
    echo "Pushed workflow: $wf_name"
  done
else
  echo "Warning: $WORKFLOWS_DIR not found — skipping workflow push"
fi

# Seed custom-rules/rules/ with the example TOML rule for Scenario 1
for toml_file in "$TEMPLATES_DIR/local-detection-rules"/*.toml; do
  [ -f "$toml_file" ] || continue
  toml_name=$(basename "$toml_file")
  toml_content=$(base64 < "$toml_file")
  EXISTING_SHA=$(gh api "repos/$GITHUB_USER/detection-rules/contents/custom-rules/rules/$toml_name" --jq '.sha' 2>/dev/null || true)
  if [ -n "$EXISTING_SHA" ]; then
    gh api -X PUT "repos/$GITHUB_USER/detection-rules/contents/custom-rules/rules/$toml_name" \
      -f message="Add example rule: $toml_name" \
      -f content="$toml_content" \
      -f sha="$EXISTING_SHA" \
      --silent
  else
    gh api -X PUT "repos/$GITHUB_USER/detection-rules/contents/custom-rules/rules/$toml_name" \
      -f message="Add example rule: $toml_name" \
      -f content="$toml_content" \
      --silent
  fi
  echo "Pushed example rule: $toml_name"
done

# ---------------------------------------------------------------------------
# Provision infrastructure (clusters, repos, secrets, branch protection)
# ---------------------------------------------------------------------------

echo ""
echo "=== Running terraform apply ==="

INFRA_DIR="$SCRIPT_DIR/../infra"
export TF_VAR_ec_api_key="$EC_API_KEY"
export TF_VAR_detection_team_lead_token="$DETECTION_TEAM_LEAD_TOKEN"
export GITHUB_TOKEN="$(gh auth token)"

terraform -chdir="$INFRA_DIR" init -upgrade -input=false -no-color 2>&1 | tail -5
terraform -chdir="$INFRA_DIR" apply -auto-approve -input=false

# ---------------------------------------------------------------------------
# Load test data into Dev cluster for Scenario 1
# ---------------------------------------------------------------------------

echo ""
echo "=== Loading test data ==="
bash "$SCRIPT_DIR/load-test-data.sh"

# ---------------------------------------------------------------------------
# Clone demo repos for presentation
# ---------------------------------------------------------------------------

echo ""
echo "=== Cloning demo repos ==="

if [ ! -d "$DEMO_DIR/detection-rules" ]; then
  gh repo clone "$GITHUB_USER/detection-rules" "$DEMO_DIR/detection-rules"
  echo "Cloned detection-rules to $DEMO_DIR/detection-rules"
else
  echo "detection-rules already exists at $DEMO_DIR/detection-rules — pulling latest main"
  git -C "$DEMO_DIR/detection-rules" checkout main 2>/dev/null || true
  git -C "$DEMO_DIR/detection-rules" pull origin main
fi

# Configure the detection-rules CLI to talk to the Dev cluster.
# The CLI only supports API key auth — username/password are ignored for kibana subcommands.
echo "Configuring detection-rules CLI for Dev cluster..."
DEV_ES_URL=$(terraform -chdir="$INFRA_DIR" output -raw dev_elasticsearch_endpoint)
DEV_ES_USER=$(terraform -chdir="$INFRA_DIR" output -raw dev_elasticsearch_username)
DEV_ES_PASS=$(terraform -chdir="$INFRA_DIR" output -raw dev_elasticsearch_password)
DEV_KB_URL=$(terraform -chdir="$INFRA_DIR" output -raw dev_kibana_endpoint)

API_KEY_RESPONSE=$(curl -sf -X POST "$DEV_ES_URL/_security/api_key" \
  -u "$DEV_ES_USER:$DEV_ES_PASS" \
  -H "Content-Type: application/json" \
  -d '{"name":"detection-rules-cli","metadata":{"created_by":"setup.sh"}}')
ENCODED_API_KEY=$(printf '%s' "$API_KEY_RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['encoded'])")

if [ -z "$ENCODED_API_KEY" ] || [ "$ENCODED_API_KEY" = "null" ]; then
  echo "Error: failed to mint API key for detection-rules CLI. Response: $API_KEY_RESPONSE" >&2
  exit 1
fi

cat > "$DEMO_DIR/detection-rules/.detection-rules-cfg.json" <<EOF
{
  "custom_rules_dir": "custom-rules",
  "kibana_url": "$DEV_KB_URL",
  "elasticsearch_url": "$DEV_ES_URL",
  "api_key": "$ENCODED_API_KEY"
}
EOF
echo "Written .detection-rules-cfg.json (Dev cluster, API key auth)"

if [ ! -d "$DEMO_DIR/terraform-dac" ]; then
  gh repo clone "$GITHUB_USER/terraform-dac" "$DEMO_DIR/terraform-dac"
  echo "Cloned terraform-dac to $DEMO_DIR/terraform-dac"
else
  echo "terraform-dac already exists at $DEMO_DIR/terraform-dac — skipping clone"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

echo ""
echo "=== Setup complete ==="
echo ""
echo "Demo repos:"
echo "  $DEMO_DIR/detection-rules   (Scenario 1: Python CLI)"
echo "  $DEMO_DIR/terraform-dac     (Scenarios 2 & 3: Terraform)"
echo ""
echo "To reset demo state between runs:"
echo "  bash $SCRIPT_DIR/reset-demo.sh"
echo ""
echo "To tear down everything:"
echo "  bash $SCRIPT_DIR/teardown.sh"
