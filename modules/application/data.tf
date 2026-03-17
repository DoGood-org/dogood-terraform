data "aws_ssm_parameter" "ecs_optimized_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

data "aws_iam_role" "ecs_execution_role" {
  name = var.ecs_execution_role_name
}

data "aws_iam_role" "ec2_role" {
  name = var.ec2_role_name
}
