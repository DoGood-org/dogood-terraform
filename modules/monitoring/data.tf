data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

# Provider default tags don't reach launch template tag specifications
data "aws_default_tags" "current" {}

locals {
  is_arm = can(regex("[a-zA-Z]+\\d+g[a-z]*\\..+", var.instance_type))
}

data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2023/${local.is_arm ? "arm64/" : ""}recommended/image_id"
}
