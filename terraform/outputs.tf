# ---------------------------------------------------------------------------
# Dev deployment outputs
# ---------------------------------------------------------------------------

output "dev_elasticsearch_endpoint" {
  description = "Elasticsearch HTTPS endpoint for the Dev deployment"
  value       = ec_deployment.dev.elasticsearch.https_endpoint
}

output "dev_kibana_endpoint" {
  description = "Kibana HTTPS endpoint for the Dev deployment"
  value       = ec_deployment.dev.kibana.https_endpoint
}

output "dev_elasticsearch_username" {
  description = "Elasticsearch username for the Dev deployment"
  value       = ec_deployment.dev.elasticsearch_username
}

output "dev_elasticsearch_password" {
  description = "Elasticsearch password for the Dev deployment"
  value       = ec_deployment.dev.elasticsearch_password
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Prod deployment outputs
# ---------------------------------------------------------------------------

output "prod_elasticsearch_endpoint" {
  description = "Elasticsearch HTTPS endpoint for the Prod deployment"
  value       = ec_deployment.prod.elasticsearch.https_endpoint
}

output "prod_kibana_endpoint" {
  description = "Kibana HTTPS endpoint for the Prod deployment"
  value       = ec_deployment.prod.kibana.https_endpoint
}

output "prod_elasticsearch_username" {
  description = "Elasticsearch username for the Prod deployment"
  value       = ec_deployment.prod.elasticsearch_username
}

output "prod_elasticsearch_password" {
  description = "Elasticsearch password for the Prod deployment"
  value       = ec_deployment.prod.elasticsearch_password
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Workflow outputs
# ---------------------------------------------------------------------------

output "active_environment" {
  description = "The environment currently targeted for rule deployment"
  value       = var.environment
}

output "next_steps" {
  description = "Workflow guidance for Detection-as-Code promotion"
  value       = <<-EOT
    Active environment: ${var.environment}

    Detection-as-Code workflow:
      1. Author/validate rules:  cd detection-rules && python -m detection_rules validate
      2. Deploy to Dev:          terraform apply -var="environment=dev"
      3. Test in Dev Kibana:     ${ec_deployment.dev.kibana.https_endpoint}
      4. Promote to Prod:        terraform apply -var="environment=prod"
      5. Verify in Prod Kibana:  ${ec_deployment.prod.kibana.https_endpoint}

    Three approaches demonstrated:
      - Approach 1: Elastic detection-rules CLI (TOML authoring + validation)
      - Approach 2: Native HCL rule (rules_hcl.tf — Service Account Interactive Login)
      - Approach 3: TOML + Terraform for_each (rules_toml.tf — reads ../detection-rules/custom-rules/*.toml)
  EOT
}
