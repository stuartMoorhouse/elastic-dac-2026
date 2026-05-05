# ---------------------------------------------------------------------------
# terraform-dac (Repo 2) — Terraform manages the full lifecycle
# ---------------------------------------------------------------------------

resource "github_repository" "terraform_dac" {
  name        = "terraform-dac"
  description = "Terraform for Elastic Security DaC demo"
  visibility  = "public"
  auto_init   = false

  has_issues   = false
  has_projects = false
  has_wiki     = false
}

# Push local terraform-dac content to the newly created repo.
# Triggers only when the repo is (re)created, not on every apply.
resource "null_resource" "terraform_dac_push" {
  depends_on = [github_repository.terraform_dac]

  triggers = {
    repo_id = github_repository.terraform_dac.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      WORK=$(mktemp -d)
      trap 'rm -rf "$WORK"' EXIT
      cp -r "${path.module}/../templates/." "$WORK/"
      rm -rf "$WORK/detection-rules-workflows"
      cd "$WORK"
      cat > .gitignore << 'GITIGNORE'
.gitignore
.claude/
CLAUDE.md

# Terraform
terraform/.terraform/
terraform/.terraform.lock.hcl
terraform/terraform.tfstate
terraform/terraform.tfstate.backup
terraform/*.tfstate.*
terraform/*.tfplan
terraform/terraform.tfvars

# macOS
.DS_Store
GITIGNORE
      git init -b main
      git add -A
      git commit -m "initial commit"
      git remote add origin "https://x-access-token:$GITHUB_TOKEN@github.com/${var.github_owner}/terraform-dac.git"
      git push -u origin main
    EOT
  }
}

resource "github_branch_protection" "terraform_dac_main" {
  repository_id  = github_repository.terraform_dac.node_id
  pattern        = "main"
  enforce_admins = true

  required_status_checks {
    strict   = true
    contexts = ["Terraform Format and Validate"]
  }

  required_pull_request_reviews {
    required_approving_review_count = 1
  }

  depends_on = [null_resource.terraform_dac_push]
}

resource "github_repository_collaborator" "detection_team_lead_terraform_dac" {
  repository = github_repository.terraform_dac.name
  username   = var.detection_team_lead_username
  permission = "write"

  depends_on = [null_resource.terraform_dac_push]
}

resource "github_actions_secret" "terraform_dac_prod_kibana_url" {
  repository  = github_repository.terraform_dac.name
  secret_name = "PROD_KIBANA_URL"
  value       = ec_deployment.prod.kibana.https_endpoint
}

resource "github_actions_secret" "terraform_dac_prod_kibana_password" {
  repository  = github_repository.terraform_dac.name
  secret_name = "PROD_KIBANA_PASSWORD"
  value       = ec_deployment.prod.elasticsearch_password
}

resource "github_actions_secret" "terraform_dac_team_lead_pat" {
  repository  = github_repository.terraform_dac.name
  secret_name = "TEAM_LEAD_PAT"
  value       = var.detection_team_lead_token
}

# ---------------------------------------------------------------------------
# detection-rules fork (Repo 1) — fork created by setup.sh; Terraform
# manages branch protection, collaborators, and secrets.
# ---------------------------------------------------------------------------

data "github_repository" "detection_rules" {
  full_name = "${var.github_owner}/detection-rules"
}

resource "github_branch_protection" "detection_rules_main" {
  repository_id  = data.github_repository.detection_rules.node_id
  pattern        = "main"
  enforce_admins = true

  required_status_checks {
    strict   = true
    contexts = ["Validate Detection Rules"]
  }

  required_pull_request_reviews {
    required_approving_review_count = 1
  }
}

resource "github_repository_collaborator" "detection_team_lead_detection_rules" {
  repository = data.github_repository.detection_rules.name
  username   = var.detection_team_lead_username
  permission = "write"
}

resource "github_actions_secret" "detection_rules_prod_kibana_url" {
  repository  = data.github_repository.detection_rules.name
  secret_name = "PROD_KIBANA_URL"
  value       = ec_deployment.prod.kibana.https_endpoint
}

resource "github_actions_secret" "detection_rules_prod_kibana_username" {
  repository  = data.github_repository.detection_rules.name
  secret_name = "PROD_KIBANA_USERNAME"
  value       = ec_deployment.prod.elasticsearch_username
}

resource "github_actions_secret" "detection_rules_prod_kibana_password" {
  repository  = data.github_repository.detection_rules.name
  secret_name = "PROD_KIBANA_PASSWORD"
  value       = ec_deployment.prod.elasticsearch_password
}

resource "github_actions_secret" "detection_rules_team_lead_pat" {
  repository  = data.github_repository.detection_rules.name
  secret_name = "TEAM_LEAD_PAT"
  value       = var.detection_team_lead_token
}

resource "null_resource" "detection_rules_prod_api_key" {
  triggers = {
    prod_deployment_id = ec_deployment.prod.id
    es_url             = ec_deployment.prod.elasticsearch.https_endpoint
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      ES_URL="${ec_deployment.prod.elasticsearch.https_endpoint}"
      ES_CREDS="elastic:${ec_deployment.prod.elasticsearch_password}"
      ENCODED=$(curl -sf -X POST "$ES_URL/_security/api_key" \
        -u "$ES_CREDS" \
        -H "Content-Type: application/json" \
        -d '{"name":"github-actions-prod"}' \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['encoded'])")
      gh secret set PROD_KIBANA_API_KEY \
        --repo "${data.github_repository.detection_rules.full_name}" \
        --body "$ENCODED"
    EOT
  }
}
