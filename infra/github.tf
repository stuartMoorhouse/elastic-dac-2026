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
