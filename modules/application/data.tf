data "aws_iam_role" "ecs_execution_role" {
  name = var.ecs_execution_role_name
}
