output "dev_elasticsearch_endpoint" {
  description = "Elasticsearch HTTPS endpoint for the Dev cluster"
  value       = ec_deployment.dev.elasticsearch.https_endpoint
}

output "dev_kibana_endpoint" {
  description = "Kibana HTTPS endpoint for the Dev cluster"
  value       = ec_deployment.dev.kibana.https_endpoint
}

output "dev_elasticsearch_username" {
  description = "Elasticsearch username for the Dev cluster"
  value       = ec_deployment.dev.elasticsearch_username
}

output "dev_elasticsearch_password" {
  description = "Elasticsearch password for the Dev cluster"
  value       = ec_deployment.dev.elasticsearch_password
  sensitive   = true
}

output "prod_kibana_endpoint" {
  description = "Kibana HTTPS endpoint for the Prod cluster"
  value       = ec_deployment.prod.kibana.https_endpoint
}

output "prod_elasticsearch_username" {
  description = "Elasticsearch username for the Prod cluster"
  value       = ec_deployment.prod.elasticsearch_username
}

output "prod_elasticsearch_password" {
  description = "Elasticsearch password for the Prod cluster"
  value       = ec_deployment.prod.elasticsearch_password
  sensitive   = true
}
