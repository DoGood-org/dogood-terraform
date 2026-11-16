# Amplify frontend: one app for all branches, kept out of the stage workspaces so a
# stage destroy never touches it. Own state: frontend/terraform.tfstate.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "dogood-infrastructure-terraform-state-69420"
    key          = "frontend/terraform.tfstate"
    region       = "us-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "dogood"
      ManagedBy = "terraform"
    }
  }
}

module "frontend" {
  source = "../modules/frontend"

  name             = var.name
  repository       = var.repository
  access_token     = var.access_token
  service_role_arn = var.service_role_arn
  domain_name      = var.domain_name
  branches         = var.branches

  environment_variables = merge(
    var.environment_variables,
    var.api_url == null ? {} : { NEXT_PUBLIC_API_URL = var.api_url }
  )
}
