locals {
  assume_ecs_tasks = jsonencode({
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
}

# --- Container instance ---

resource "aws_iam_role" "host" {
  name = "${var.stage}-monitoring-host-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "${var.stage}-monitoring-host-role"
    Service = "monitoring"
  }
}

resource "aws_iam_role_policy_attachment" "host" {
  for_each = toset([
    "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.host.name
  policy_arn = each.value
}

resource "aws_iam_instance_profile" "host" {
  name = "${var.stage}-monitoring-host"
  role = aws_iam_role.host.name

  tags = {
    Name    = "${var.stage}-monitoring-host"
    Service = "monitoring"
  }
}

# --- Task execution role: logs, image pulls (public), secrets ---

resource "aws_iam_role" "execution" {
  name               = "${var.stage}-monitoring-execution-role"
  assume_role_policy = local.assume_ecs_tasks

  tags = {
    Name    = "${var.stage}-monitoring-execution-role"
    Service = "monitoring"
  }
}

resource "aws_iam_role_policy" "execution" {
  name = "${var.stage}-monitoring-execution-policy"
  role = aws_iam_role.execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["${local.log_group_arn_prefix}/*:*"]
      },
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = [
          aws_secretsmanager_secret.grafana.arn,
          aws_secretsmanager_secret.db_monitoring.arn,
          var.db_master_secret_arn,
        ]
      },
    ]
  })
}

# --- Task role: Grafana CloudWatch data source, Prometheus ECS/EC2 discovery, ECS Exec ---

resource "aws_iam_role" "task" {
  name               = "${var.stage}-monitoring-task-role"
  assume_role_policy = local.assume_ecs_tasks

  tags = {
    Name    = "${var.stage}-monitoring-task-role"
    Service = "monitoring"
  }
}

resource "aws_iam_role_policy" "task" {
  name = "${var.stage}-monitoring-task-policy"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "GrafanaCloudWatch"
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
          "oam:ListSinks",
          "oam:ListAttachedLinks",
        ]
        Resource = ["*"]
      },
      {
        Sid    = "PrometheusDiscovery"
        Effect = "Allow"
        Action = [
          "ecs:ListClusters",
          "ecs:DescribeClusters",
          "ecs:ListServices",
          "ecs:DescribeServices",
          "ecs:ListTasks",
          "ecs:DescribeTasks",
          "ecs:DescribeContainerInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeAvailabilityZones",
        ]
        Resource = ["*"]
      },
      {
        Sid    = "EcsExec"
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
