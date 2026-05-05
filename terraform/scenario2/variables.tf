variable "kibana_endpoint" {
  description = "Kibana HTTPS endpoint (e.g. https://my-cluster.kb.us-east-1.aws.elastic-cloud.com:9243)"
  type        = string
}

variable "kibana_username" {
  description = "Kibana username"
  type        = string
  default     = "elastic"
}

variable "kibana_password" {
  description = "Kibana password"
  type        = string
  sensitive   = true
}
