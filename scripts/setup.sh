#!/usr/bin/env bash
set -euo pipefail

# Bootstrap script for the Detection-as-Code demo.
# Sets up Repo 1 (detection-rules fork) and Repo 2 (terraform-dac) on GitHub.
# This repo (elastic-dac-2026) is never shown to the audience.
#
# Usage: bash scripts/setup.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------------------
# Prerequisites check
# ---------------------------------------------------------------------------

check_deps() {
  local missing=()
  for cmd in gh git jq terraform; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    echo "Error: missing required tools: ${missing[*]}" >&2
    echo "" >&2
    echo "Install instructions:" >&2
    echo "  gh        https://cli.github.com" >&2
    echo "  git       https://git-scm.com" >&2
    echo "  jq        https://stedolan.github.io/jq/ or: brew install jq" >&2
    echo "  terraform https://developer.hashicorp.com/terraform/install" >&2
    exit 1
  fi
}

check_deps

if ! gh auth status &>/dev/null; then
  echo "Error: gh is not authenticated." >&2
  echo "Run: gh auth login" >&2
  exit 1
fi

if [ -z "${EC_API_KEY:-}" ]; then
  echo "Error: EC_API_KEY environment variable is not set." >&2
  echo "Export your Elastic Cloud API key: export EC_API_KEY=<your-key>" >&2
  exit 1
fi

# GITHUB_TOKEN is optional — gh CLI will use its own token if not set
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Note: GITHUB_TOKEN not set. Using gh CLI's authenticated token."
fi

echo "Prerequisites OK."
echo ""

# ---------------------------------------------------------------------------
# Part 1: Create terraform-dac (Repo 2)
# ---------------------------------------------------------------------------

echo "=== Part 1: terraform-dac ==="

gh repo create stuartMoorhouse/terraform-dac \
  --private \
  --description "Terraform for Elastic Security DaC demo" 2>/dev/null \
  || echo "terraform-dac already exists, skipping creation"

TERRAFORM_DAC_DIR="$(cd "$SCRIPT_DIR/../../terraform-dac" 2>/dev/null && pwd)" || true
if [ -z "$TERRAFORM_DAC_DIR" ] || [ ! -d "$TERRAFORM_DAC_DIR" ]; then
  echo "Error: terraform-dac directory not found at $SCRIPT_DIR/../../terraform-dac" >&2
  exit 1
fi

if [ ! -d "$TERRAFORM_DAC_DIR/.git" ]; then
  echo "Error: $TERRAFORM_DAC_DIR is not a git repository." >&2
  exit 1
fi

cd "$TERRAFORM_DAC_DIR"
git add -A
git diff --cached --quiet || git commit -m "initial commit"
git push -u origin main 2>/dev/null || git push origin main
cd "$SCRIPT_DIR"

gh secret set EC_API_KEY --repo stuartMoorhouse/terraform-dac --body "$EC_API_KEY"
echo "Set EC_API_KEY secret in terraform-dac"
echo ""

# ---------------------------------------------------------------------------
# Part 2: Fork and configure detection-rules (Repo 1)
# ---------------------------------------------------------------------------

echo "=== Part 2: detection-rules fork ==="

gh repo fork elastic/detection-rules --org "" --clone=false 2>/dev/null || true

echo "Waiting for fork to be ready..."
sleep 5

# Delete all branches except main
echo "Cleaning up inherited branches..."
BRANCHES=$(gh api repos/stuartMoorhouse/detection-rules/branches --paginate --jq '.[].name' 2>/dev/null | grep -v '^main$' || true)
for branch in $BRANCHES; do
  gh api -X DELETE "repos/stuartMoorhouse/detection-rules/git/refs/heads/$branch" 2>/dev/null || true
done
echo "Branch cleanup complete"

# Create dev branch
echo "Creating dev branch..."
MAIN_SHA=$(gh api repos/stuartMoorhouse/detection-rules/git/refs/heads/main --jq '.object.sha')
gh api -X POST repos/stuartMoorhouse/detection-rules/git/refs \
  -f ref="refs/heads/dev" \
  -f sha="$MAIN_SHA" 2>/dev/null || echo "dev branch already exists"
echo "Created dev branch"

# Configure fork settings
gh api -X PATCH repos/stuartMoorhouse/detection-rules \
  -f has_issues=true \
  -f has_projects=false \
  -f has_wiki=false \
  --silent
echo "Configured fork settings"

# Remove inherited workflows
echo "Removing inherited workflows..."
WORKFLOW_FILES=$(gh api repos/stuartMoorhouse/detection-rules/contents/.github/workflows --jq '.[].name' 2>/dev/null || true)
for wf in $WORKFLOW_FILES; do
  SHA=$(gh api "repos/stuartMoorhouse/detection-rules/contents/.github/workflows/$wf" --jq '.sha' 2>/dev/null || true)
  if [ -n "$SHA" ]; then
    gh api -X DELETE "repos/stuartMoorhouse/detection-rules/contents/.github/workflows/$wf" \
      -f message="Remove inherited workflow: $wf" \
      -f sha="$SHA" \
      --silent 2>/dev/null || true
  fi
done
echo "Inherited workflows removed"

# Push our workflow files from terraform-dac/detection-rules-workflows/
WORKFLOWS_DIR="$TERRAFORM_DAC_DIR/detection-rules-workflows"
if [ -d "$WORKFLOWS_DIR" ]; then
  for wf_file in "$WORKFLOWS_DIR"/*.yml; do
    [ -f "$wf_file" ] || continue
    wf_name=$(basename "$wf_file")
    wf_content=$(base64 < "$wf_file")
    EXISTING_SHA=$(gh api "repos/stuartMoorhouse/detection-rules/contents/.github/workflows/$wf_name" --jq '.sha' 2>/dev/null || true)
    if [ -n "$EXISTING_SHA" ]; then
      gh api -X PUT "repos/stuartMoorhouse/detection-rules/contents/.github/workflows/$wf_name" \
        -f message="Add DaC demo workflow: $wf_name" \
        -f content="$wf_content" \
        -f sha="$EXISTING_SHA" \
        --silent
    else
      gh api -X PUT "repos/stuartMoorhouse/detection-rules/contents/.github/workflows/$wf_name" \
        -f message="Add DaC demo workflow: $wf_name" \
        -f content="$wf_content" \
        --silent
    fi
    echo "Pushed workflow: $wf_name"
  done
else
  echo "Warning: $WORKFLOWS_DIR not found — skipping workflow push"
fi

# Create custom-rules/rules/ directory with a .gitkeep
gh api -X PUT "repos/stuartMoorhouse/detection-rules/contents/custom-rules/rules/.gitkeep" \
  -f message="Add custom-rules directory" \
  -f content="$(printf '' | base64)" \
  --silent 2>/dev/null || true
echo "Created custom-rules/rules/ directory"
echo ""

# ---------------------------------------------------------------------------
# Part 3: Branch protection on detection-rules
# ---------------------------------------------------------------------------

echo "=== Part 3: Branch protection ==="

gh api -X PUT repos/stuartMoorhouse/detection-rules/branches/dev/protection \
  --input - <<'EOF'
{
  "required_status_checks": {"strict": false, "contexts": ["Validate Detection Rules"]},
  "enforce_admins": false,
  "required_pull_request_reviews": {"required_approving_review_count": 1},
  "restrictions": null
}
EOF

gh api -X PUT repos/stuartMoorhouse/detection-rules/branches/main/protection \
  --input - <<'EOF'
{
  "required_status_checks": {"strict": true, "contexts": ["Validate Detection Rules"]},
  "enforce_admins": true,
  "required_pull_request_reviews": {"required_approving_review_count": 1},
  "restrictions": null
}
EOF

echo "Branch protection configured"
echo ""

# ---------------------------------------------------------------------------
# Part 4: Next steps
# ---------------------------------------------------------------------------

echo "=== Bootstrap complete ==="
echo ""
echo "Next step: trigger the initial Terraform deployment."
echo "This creates the Dev and Prod Elastic Cloud clusters."
echo ""
echo "Run: gh workflow run deploy-dev.yml --repo stuartMoorhouse/terraform-dac"
echo ""
echo "After it completes, get the cluster credentials:"
echo "  gh run list --repo stuartMoorhouse/terraform-dac --workflow=deploy-dev.yml"
echo "  gh run view <run-id> --log --repo stuartMoorhouse/terraform-dac"
echo ""
echo "Then set secrets in the detection-rules fork:"
echo "  bash scripts/set-detection-rules-secrets.sh"
