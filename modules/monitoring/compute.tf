locals {
  grafana_port = 3000

  log_group_name = "/aws/ecs/${var.stage}/grafana"
  log_group_arn  = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}"
}

module "grafana" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 7.0"

  name        = "grafana"
  family      = "${var.stage}-grafana"
  cluster_arn = var.cluster_arn

  cpu    = var.task_cpu
  memory = var.task_memory

  requires_compatibilities = ["FARGATE"]
  launch_type              = "FARGATE"
  network_mode             = "awsvpc"

  runtime_platform = {
    cpu_architecture        = "ARM64"
    operating_system_family = "LINUX"
  }

  create_task_exec_iam_role = false
  create_task_exec_policy   = false
  task_exec_iam_role_arn    = aws_iam_role.grafana_execution.arn

  create_iam_role       = false
  create_tasks_iam_role = false
  tasks_iam_role_arn    = aws_iam_role.grafana_task.arn

  enable_execute_command = true

  container_definitions = {
    grafana = {
      image     = var.grafana_image
      essential = true

      # The image's ENTRYPOINT is /run.sh; start.sh writes provisioning files and then execs it.
      entrypoint = ["sh", "-c"]
      command    = [file("${path.module}/templates/start.sh")]

      # Grafana writes its SQLite database and plugins under /var/lib/grafana.
      readonlyRootFilesystem = false

      linuxParameters = {
        initProcessEnabled = true
      }

      cloudwatch_log_group_name = local.log_group_name

      portMappings = [{
        containerPort = local.grafana_port
        hostPort      = local.grafana_port
        protocol      = "tcp"
      }]

      # Only settings that differ from Grafana's defaults (port 3000, admin user,
      # no sign-up/anonymous/embedding are already the defaults).
      environment = [
        # Default provisioning path is under /etc and not writable by the grafana user.
        { name = "GF_PATHS_PROVISIONING", value = "/var/lib/grafana/provisioning" },
        { name = "GF_SECURITY_DISABLE_GRAVATAR", value = "true" },
        { name = "GF_SNAPSHOTS_EXTERNAL_ENABLED", value = "false" },
        { name = "GF_PLUGINS_PLUGIN_ADMIN_ENABLED", value = "false" },
        { name = "GF_ANALYTICS_REPORTING_ENABLED", value = "false" },
        { name = "GF_ANALYTICS_CHECK_FOR_UPDATES", value = "false" },
        { name = "GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES", value = "false" },
        { name = "GF_NEWS_NEWS_FEED_ENABLED", value = "false" },
        # Data sources may only use the task role, not user-entered keys or assumed roles.
        { name = "GF_AWS_ALLOWED_AUTH_PROVIDERS", value = "default" },
        { name = "GF_AWS_ASSUME_ROLE_ENABLED", value = "false" },
        {
          name = "DATASOURCES_YAML"
          value = templatefile("${path.module}/templates/datasources.yaml.tftpl", {
            region = data.aws_region.current.region
          })
        },
      ]

      secrets = [{
        name      = "GF_SECURITY_ADMIN_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.grafana.arn}:admin_password::"
      }]
    }
  }

  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }

  desired_count      = 1
  enable_autoscaling = false

  subnet_ids            = [var.subnet_id]
  create_security_group = false
  security_group_ids    = [module.grafana_sg.id]
  assign_public_ip      = true

  depends_on = [aws_iam_role_policy.grafana_execution, aws_secretsmanager_secret_version.grafana]

  tags = {
    Name    = "${var.stage}-grafana-service"
    Service = "monitoring"
  }
}
