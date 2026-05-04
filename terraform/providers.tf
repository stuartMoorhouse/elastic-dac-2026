terraform {
  required_version = ">= 1.5"

  required_providers {
    ec = {
      source  = "elastic/ec"
      version = "~> 0.10.0"
    }
    elasticstack = {
      source  = "elastic/elasticstack"
      version = "~> 0.14"
    }
    toml = {
      source  = "Tobotimus/toml"
      version = "0.3.0"
    }
  }
}

provider "ec" {
  apikey = var.ec_api_key
}

provider "elasticstack" {
  alias = "dev"
  elasticsearch {
    endpoints = [ec_deployment.dev.elasticsearch.https_endpoint]
    username  = ec_deployment.dev.elasticsearch_username
    password  = ec_deployment.dev.elasticsearch_password
  }
  kibana {
    endpoints = [ec_deployment.dev.kibana.https_endpoint]
    username  = ec_deployment.dev.elasticsearch_username
    password  = ec_deployment.dev.elasticsearch_password
  }
}

provider "elasticstack" {
  alias = "prod"
  elasticsearch {
    endpoints = [ec_deployment.prod.elasticsearch.https_endpoint]
    username  = ec_deployment.prod.elasticsearch_username
    password  = ec_deployment.prod.elasticsearch_password
  }
  kibana {
    endpoints = [ec_deployment.prod.kibana.https_endpoint]
    username  = ec_deployment.prod.elasticsearch_username
    password  = ec_deployment.prod.elasticsearch_password
  }
}
