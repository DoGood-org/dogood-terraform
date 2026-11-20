data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "inline" {
  statement {
    sid       = "GetSpecificSecret"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [
        var.secret_arn,
        var.rds_secret_arn
        ]
  }

  statement {
    sid       = "RdsIamAuth"
    actions   = ["rds-db:connect"]
    resources = ["arn:aws:rds-db:${local.region}:${local.account_id}:dbuser:${var.rds_resource_id}/app_iam"]
  }
}