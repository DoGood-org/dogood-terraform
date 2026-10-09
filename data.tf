data "aws_ecr_repository" "backend" {
  name = var.ecr_repository_name

  lifecycle {
    precondition {
      condition     = endswith(var.ecr_repository_name, "-${var.stage}")
      error_message = "ECR repository \"${var.ecr_repository_name}\" does not belong to stage \"${var.stage}\". Expected a name ending with \"-${var.stage}\", e.g. \"dogood/dogood-backend-${var.stage}\"."
    }
  }
}

data "aws_caller_identity" "current" {
  lifecycle {
    precondition {
      condition     = terraform.workspace == var.stage
      error_message = "Workspace \"${terraform.workspace}\" does not match stage \"${var.stage}\". Run `terraform workspace select -or-create ${var.stage}`."
    }
  }
}
