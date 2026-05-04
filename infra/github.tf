# ---------------------------------------------------------------------------
# terraform-dac (Repo 2) — Terraform manages the full lifecycle
# ---------------------------------------------------------------------------

resource "github_repository" "terraform_dac" {
  name        = "terraform-dac"
  description = "Terraform for Elastic Security DaC demo"
  visibility  = "private"
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
      cp -r "${path.module}/../terraform-dac/." "$WORK/"
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

resource "github_branch" "terraform_dac_dev" {
  repository    = github_repository.terraform_dac.name
  branch        = "dev"
  source_branch = "main"

  depends_on = [null_resource.terraform_dac_push]
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

resource "github_branch_protection" "terraform_dac_dev" {
  repository_id = github_repository.terraform_dac.node_id
  pattern       = "dev"

  required_status_checks {
    strict   = false
    contexts = ["Terraform Format and Validate"]
  }

  required_pull_request_reviews {
    required_approving_review_count = 1
  }

  depends_on = [github_branch.terraform_dac_dev]
}

resource "github_actions_secret" "terraform_dac_dev_kibana_url" {
  repository      = github_repository.terraform_dac.name
  secret_name     = "DEV_KIBANA_URL"
  plaintext_value = ec_deployment.dev.kibana.https_endpoint
}

resource "github_actions_secret" "terraform_dac_dev_kibana_password" {
  repository      = github_repository.terraform_dac.name
  secret_name     = "DEV_KIBANA_PASSWORD"
  plaintext_value = ec_deployment.dev.elasticsearch_password
}

resource "github_actions_secret" "terraform_dac_prod_kibana_url" {
  repository      = github_repository.terraform_dac.name
  secret_name     = "PROD_KIBANA_URL"
  plaintext_value = ec_deployment.prod.kibana.https_endpoint
}

resource "github_actions_secret" "terraform_dac_prod_kibana_password" {
  repository      = github_repository.terraform_dac.name
  secret_name     = "PROD_KIBANA_PASSWORD"
  plaintext_value = ec_deployment.prod.elasticsearch_password
}

# ---------------------------------------------------------------------------
# detection-rules fork (Repo 1) — fork created by setup.sh; Terraform
# manages branch protection and secrets.
# ---------------------------------------------------------------------------

data "github_repository" "detection_rules" {
  full_name = "${var.github_owner}/detection-rules"
}

resource "github_branch_protection" "detection_rules_dev" {
  repository_id = data.github_repository.detection_rules.node_id
  pattern       = "dev"

  required_status_checks {
    strict   = false
    contexts = ["Validate Detection Rules"]
  }

  required_pull_request_reviews {
    required_approving_review_count = 1
  }
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

resource "github_actions_secret" "detection_rules_dev_kibana_url" {
  repository      = data.github_repository.detection_rules.name
  secret_name     = "DEV_KIBANA_URL"
  plaintext_value = ec_deployment.dev.kibana.https_endpoint
}

resource "github_actions_secret" "detection_rules_dev_kibana_username" {
  repository      = data.github_repository.detection_rules.name
  secret_name     = "DEV_KIBANA_USERNAME"
  plaintext_value = ec_deployment.dev.elasticsearch_username
}

resource "github_actions_secret" "detection_rules_dev_kibana_password" {
  repository      = data.github_repository.detection_rules.name
  secret_name     = "DEV_KIBANA_PASSWORD"
  plaintext_value = ec_deployment.dev.elasticsearch_password
}

resource "github_actions_secret" "detection_rules_prod_kibana_url" {
  repository      = data.github_repository.detection_rules.name
  secret_name     = "PROD_KIBANA_URL"
  plaintext_value = ec_deployment.prod.kibana.https_endpoint
}

resource "github_actions_secret" "detection_rules_prod_kibana_username" {
  repository      = data.github_repository.detection_rules.name
  secret_name     = "PROD_KIBANA_USERNAME"
  plaintext_value = ec_deployment.prod.elasticsearch_username
}

resource "github_actions_secret" "detection_rules_prod_kibana_password" {
  repository      = data.github_repository.detection_rules.name
  secret_name     = "PROD_KIBANA_PASSWORD"
  plaintext_value = ec_deployment.prod.elasticsearch_password
}
