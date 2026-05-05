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
TERRAFORM_DAC_DIR="$(cd "$SCRIPT_DIR/../terraform-dac" 2>/dev/null && pwd)" || true

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

if [ -z "$TERRAFORM_DAC_DIR" ] || [ ! -d "$TERRAFORM_DAC_DIR" ]; then
  echo "Error: terraform-dac directory not found at $SCRIPT_DIR/../terraform-dac" >&2
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

gh repo fork elastic/detection-rules --clone=false 2>/dev/null || true

echo "Waiting for fork to be ready..."
sleep 5

# Delete all branches except main (elastic/detection-rules has hundreds)
echo "Cleaning up inherited branches..."
BRANCHES=$(gh api "repos/$GITHUB_USER/detection-rules/branches" --paginate --jq '.[].name' 2>/dev/null | grep -v '^main$' || true)
for branch in $BRANCHES; do
  gh api -X DELETE "repos/$GITHUB_USER/detection-rules/git/refs/heads/$branch" 2>/dev/null || true
done
echo "Branch cleanup complete"

# Create dev branch
echo "Creating dev branch..."
MAIN_SHA=$(gh api "repos/$GITHUB_USER/detection-rules/git/refs/heads/main" --jq '.object.sha')
gh api -X POST "repos/$GITHUB_USER/detection-rules/git/refs" \
  -f ref="refs/heads/dev" \
  -f sha="$MAIN_SHA" 2>/dev/null || echo "dev branch already exists"
echo "Created dev branch"

# Minimal fork settings
gh api -X PATCH "repos/$GITHUB_USER/detection-rules" \
  -f has_issues=true \
  -f has_projects=false \
  -f has_wiki=false \
  --silent
echo "Configured fork settings"

# Remove inherited upstream workflows
echo "Removing inherited workflows..."
WORKFLOW_FILES=$(gh api "repos/$GITHUB_USER/detection-rules/contents/.github/workflows" --jq '.[].name' 2>/dev/null || true)
for wf in $WORKFLOW_FILES; do
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
WORKFLOWS_DIR="$TERRAFORM_DAC_DIR/detection-rules-workflows"
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

# Create custom-rules/rules/ directory
gh api -X PUT "repos/$GITHUB_USER/detection-rules/contents/custom-rules/rules/.gitkeep" \
  -f message="Add custom-rules directory" \
  -f content="$(printf '' | base64)" \
  --silent 2>/dev/null || true
echo "Created custom-rules/rules/ directory"

# ---------------------------------------------------------------------------
# Provision infrastructure (clusters, repos, secrets, branch protection)
# ---------------------------------------------------------------------------

echo ""
echo "=== Running terraform apply ==="

INFRA_DIR="$SCRIPT_DIR/../infra"
export TF_VAR_ec_api_key="$EC_API_KEY"
export GITHUB_TOKEN="$(gh auth token)"

terraform -chdir="$INFRA_DIR" init -upgrade -input=false -no-color 2>&1 | tail -5
terraform -chdir="$INFRA_DIR" apply -auto-approve -input=false

# ---------------------------------------------------------------------------
# Clone demo repos for presentation
# ---------------------------------------------------------------------------

echo ""
echo "=== Cloning demo repos ==="

if [ ! -d "$DEMO_DIR/detection-rules" ]; then
  gh repo clone "$GITHUB_USER/detection-rules" "$DEMO_DIR/detection-rules"
  echo "Cloned detection-rules to $DEMO_DIR/detection-rules"
else
  echo "detection-rules already exists at $DEMO_DIR/detection-rules — skipping clone"
fi

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
