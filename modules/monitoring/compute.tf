locals {
  log_group_name = "/aws/ecs/${var.stage}/grafana"
  log_group_arn  = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}"
}

module "grafana" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 7.0"

  name         = "grafana"
  family       = "${var.stage}-grafana"
  cluster_arn  = var.cluster_arn
  track_latest = false

  cpu    = 256
  memory = 1024

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
      image     = "grafana/grafana:13.2.4@sha256:dbbc38ea21103cefb50396340cd88afec779c7e070b0a7bf5a75b4ce46651d3f"
      essential = true

      entrypoint             = ["sh", "-c"]
      command                = [file("${path.module}/templates/start.sh")]
      readonlyRootFilesystem = false

      mountPoints = var.efs_enabled ? [{
        sourceVolume  = "grafana-data"
        containerPath = "/var/lib/grafana"
      }] : []

      linuxParameters = {
        initProcessEnabled = true
      }

      cloudwatch_log_group_name = local.log_group_name

      portMappings = [{
        containerPort = 3000
        hostPort      = 3000
        protocol      = "tcp"
      }]

      environment = [
        { name = "GF_PATHS_PROVISIONING", value = "/var/lib/grafana/provisioning" },
        { name = "GF_SECURITY_DISABLE_GRAVATAR", value = "true" },
        { name = "GF_SNAPSHOTS_EXTERNAL_ENABLED", value = "false" },
        { name = "GF_PLUGINS_PLUGIN_ADMIN_ENABLED", value = "false" },
        { name = "GF_ANALYTICS_REPORTING_ENABLED", value = "false" },
        { name = "GF_ANALYTICS_CHECK_FOR_UPDATES", value = "false" },
        { name = "GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES", value = "false" },
        { name = "GF_NEWS_NEWS_FEED_ENABLED", value = "false" },
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

  volume = {
    for name, config in {
      grafana-data = {
        efs_volume_configuration = {
          file_system_id     = one(aws_efs_file_system.grafana[*].id)
          transit_encryption = "ENABLED"
          authorization_config = {
            access_point_id = one(aws_efs_access_point.grafana[*].id)
          }
        }
      }
    } : name => config if var.efs_enabled
  }

  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }

  # Single SQLite writer on EFS
  deployment_maximum_percent         = var.efs_enabled ? 100 : 200
  deployment_minimum_healthy_percent = var.efs_enabled ? 0 : 66
  availability_zone_rebalancing      = "DISABLED"

  desired_count      = 1
  enable_autoscaling = false

  subnet_ids            = [var.subnet_id]
  create_security_group = false
  security_group_ids    = [module.grafana_sg.id]
  assign_public_ip      = true

  depends_on = [aws_iam_role_policy.grafana_execution, aws_secretsmanager_secret_version.grafana, aws_efs_mount_target.grafana]

  tags = {
    Name    = "${var.stage}-grafana-service"
    Service = "monitoring"
  }
}
