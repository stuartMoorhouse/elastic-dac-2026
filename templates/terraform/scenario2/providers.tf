terraform {
  required_version = ">= 1.8"

  required_providers {
    elasticstack = {
      source  = "elastic/elasticstack"
      version = "~> 0.14"
    }
  }
}

provider "elasticstack" {
  kibana {
    endpoints = [var.kibana_endpoint]
    username  = var.kibana_username
    password  = var.kibana_password
  }
}
