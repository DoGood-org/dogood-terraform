terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "dogood-infrastructure-terraform-state-69420"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-west-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region  = "us-west-1"
  profile = var.aws_profile

  default_tags {
    tags = {
      Project   = "dogood"
      ManagedBy = "terraform"
    }
  }
}

variable "aws_profile" {
  type    = string
  default = null
}

data "aws_caller_identity" "current" {}

locals {
  state_bucket = "dogood-infrastructure-terraform-state-69420"
  account_id   = data.aws_caller_identity.current.account_id

  # AdministratorAccess holders (user Terraform, groups admin and security)
  state_readers = [
    "arn:aws:iam::${local.account_id}:root",
    "arn:aws:iam::${local.account_id}:user/Terraform",
    "arn:aws:iam::${local.account_id}:user/Oleh.DevOps",
    "arn:aws:iam::${local.account_id}:user/Vitalii",
    "arn:aws:iam::${local.account_id}:user/devops",
  ]
}

# Terraform state
resource "aws_s3_bucket_policy" "state" {
  bucket = local.state_bucket

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyReadExceptAdmins"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource  = "arn:aws:s3:::${local.state_bucket}/*"
        Condition = {
          ArnNotEquals = { "aws:PrincipalArn" = local.state_readers }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          "arn:aws:s3:::${local.state_bucket}",
          "arn:aws:s3:::${local.state_bucket}/*",
        ]
        Condition = {
          Bool = { "aws:SecureTransport" = "false" }
        }
      },
    ]
  })
}
