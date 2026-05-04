data "ec_stack" "latest" {
  version_regex = "latest"
  region        = var.region
}

resource "ec_deployment" "dev" {
  name                   = var.deployment_name_dev
  region                 = var.region
  version                = data.ec_stack.latest.version
  deployment_template_id = var.deployment_template_id

  elasticsearch = {
    hot = {
      autoscaling = {}
      size        = var.elasticsearch_size
      zone_count  = 1
    }
  }

  kibana = {
    size       = "1g"
    zone_count = 1
  }
}

resource "ec_deployment" "prod" {
  name                   = var.deployment_name_prod
  region                 = var.region
  version                = data.ec_stack.latest.version
  deployment_template_id = var.deployment_template_id

  elasticsearch = {
    hot = {
      autoscaling = {}
      size        = var.elasticsearch_size
      zone_count  = 1
    }
  }

  kibana = {
    size       = "1g"
    zone_count = 1
  }
}
