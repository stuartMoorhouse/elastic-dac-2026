terraform {
  required_version = ">= 1.8"

  required_providers {
    ec = {
      source  = "elastic/ec"
      version = "~> 0.10.0"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "ec" {
  apikey = var.ec_api_key
}

# Token is read from GITHUB_TOKEN env var automatically.
# Run: export GITHUB_TOKEN=$(gh auth token)
provider "github" {
  owner = var.github_owner
}
