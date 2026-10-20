resource "aws_iam_role" "grafana_execution" {
  name = "${var.stage}-grafana-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "${var.stage}-grafana-execution-role"
    Service = "monitoring"
  }
}

# The image comes from Docker Hub, so no ECR permissions are needed.
resource "aws_iam_role_policy" "grafana_execution" {
  name = "${var.stage}-grafana-execution-policy"
  role = aws_iam_role.grafana_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["${local.log_group_arn}:*"]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.grafana.arn]
      },
    ]
  })
}

resource "aws_iam_role" "grafana_task" {
  name = "${var.stage}-grafana-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })

  tags = {
    Name    = "${var.stage}-grafana-task-role"
    Service = "monitoring"
  }
}

# Read-only CloudWatch metrics for the Grafana data source. Logs access is
# deliberately left out until app logs are confirmed free of personal data.
resource "aws_iam_role_policy" "grafana_task" {
  name = "${var.stage}-grafana-task-policy"
  role = aws_iam_role.grafana_task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:DescribeAlarmsForMetric",
          "cloudwatch:DescribeAlarmHistory",
          "cloudwatch:DescribeAlarms",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetInsightRuleReport",
          "ec2:DescribeRegions",
          "tag:GetResources",
          # Cross-account observability lookup the data source runs on every query editor load.
          "oam:ListSinks",
          "oam:ListAttachedLinks",
        ]
        Resource = ["*"]
      },
      {
        # ECS Exec agent channel, used by the SSM port-forwarding tunnel.
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
        ]
        Resource = ["*"]
      },
    ]
  })
}
