variable "ec_api_key" {
  description = "Elastic Cloud API key"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Target environment: dev or prod"
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be dev or prod"
  }
}

variable "region" {
  description = "Elastic Cloud region"
  type        = string
  default     = "gcp-europe-north1"
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.region))
    error_message = "region must be a valid Elastic Cloud region identifier"
  }
}

variable "deployment_template_id" {
  description = "Elastic Cloud deployment template ID"
  type        = string
  default     = "gcp-storage-optimized"
}

variable "deployment_name_dev" {
  description = "Name for the Dev deployment"
  type        = string
  default     = "dac-demo-dev"
}

variable "deployment_name_prod" {
  description = "Name for the Prod deployment"
  type        = string
  default     = "dac-demo-prod"
}

variable "elasticsearch_size" {
  description = "Elasticsearch node size (memory)"
  type        = string
  default     = "8g"
  validation {
    condition     = contains(["1g", "2g", "4g", "8g", "16g", "32g", "64g"], var.elasticsearch_size)
    error_message = "elasticsearch_size must be one of: 1g, 2g, 4g, 8g, 16g, 32g, 64g"
  }
}
