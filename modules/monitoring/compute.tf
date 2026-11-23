locals {
  log_group_prefix     = "/aws/ecs/${var.stage}/monitoring"
  log_group_arn_prefix = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_prefix}"

  db_monitoring_user = "monitoring"

  prometheus_config = templatefile("${path.module}/templates/prometheus.yml.tftpl", {
    stage                = var.stage
    region               = data.aws_region.current.region
    backend_cluster_arn  = var.backend_cluster_arn
    backend_service_name = var.backend_service_name
    app_port             = var.app_port
    backend_metrics_path = var.backend_metrics_path
    ecs_exporter_port    = var.ecs_exporter_port
    node_exporter_port   = var.node_exporter_port
    grafana_port         = var.grafana_port
    probe_url            = var.probe_url
  })
}

# Task definition prerequisites: execution role with its policy and the secrets. A barrier
# instead of module depends_on, which would defer the module's data sources.
resource "terraform_data" "prerequisites" {
  input = aws_iam_role.execution.arn

  depends_on = [
    aws_iam_role_policy.execution,
    aws_secretsmanager_secret_version.grafana,
    aws_secretsmanager_secret_version.db_monitoring,
  ]
}

# One task with all monitoring containers (awsvpc, shared localhost):
# Prometheus :9090, Grafana :3000, postgres_exporter :9187, blackbox_exporter :9115.
# Backend tasks and NAT instances are discovered by Prometheus itself (aws_sd_configs, ECS
# and EC2 APIs through NAT), so there is no separate discovery sidecar.
module "service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 7.0"

  name         = "monitoring"
  family       = "${var.stage}-monitoring"
  cluster_arn  = aws_ecs_cluster.this.arn
  track_latest = false

  launch_type              = "EC2"
  requires_compatibilities = ["EC2"]

  # Whole t4g.small minus OS / ECS agent
  cpu    = 2048
  memory = 1536

  runtime_platform = {
    cpu_architecture        = local.is_arm ? "ARM64" : "X86_64"
    operating_system_family = "LINUX"
  }

  create_task_exec_iam_role = false
  create_task_exec_policy   = false
  task_exec_iam_role_arn    = terraform_data.prerequisites.output

  create_iam_role       = false
  create_tasks_iam_role = false
  tasks_iam_role_arn    = aws_iam_role.task.arn

  enable_execute_command = true

  container_definitions = {
    prometheus = {
      image     = "prom/prometheus:v3.16.0-busybox@sha256:e04987641b57704f408e31f6373ba4138ecf27cb4a165d24aabb6c38fddd0f06"
      essential = true

      memoryReservation = 512

      entrypoint = ["sh", "-c"]
      command = [<<-EOT
        set -e
        printf '%s\n' "$PROMETHEUS_YML" > /tmp/prometheus.yml
        exec /bin/prometheus --config.file=/tmp/prometheus.yml --storage.tsdb.path=/prometheus \
          --storage.tsdb.retention.time=${var.prometheus_retention_time} \
          --storage.tsdb.retention.size=${var.prometheus_retention_size}
      EOT
      ]
      readonlyRootFilesystem = false

      environment = [
        { name = "PROMETHEUS_YML", value = local.prometheus_config },
      ]

      mountPoints = [{
        sourceVolume  = "prometheus-data"
        containerPath = "/prometheus"
      }]

      portMappings = [{ containerPort = 9090, hostPort = 9090, protocol = "tcp" }]

      linuxParameters = { initProcessEnabled = true }

      cloudwatch_log_group_name = "${local.log_group_prefix}/prometheus"
    }

    grafana = {
      image     = "grafana/grafana:13.2.4@sha256:dbbc38ea21103cefb50396340cd88afec779c7e070b0a7bf5a75b4ce46651d3f"
      essential = true

      memoryReservation = 256

      entrypoint             = ["sh", "-c"]
      command                = [file("${path.module}/templates/start.sh")]
      readonlyRootFilesystem = false

      mountPoints = [{
        sourceVolume  = "grafana-data"
        containerPath = "/var/lib/grafana"
      }]

      portMappings = [{ containerPort = var.grafana_port, hostPort = var.grafana_port, protocol = "tcp" }]

      linuxParameters = { initProcessEnabled = true }

      dependsOn = [{ containerName = "prometheus", condition = "START" }]

      cloudwatch_log_group_name = "${local.log_group_prefix}/grafana"

      environment = concat(
        [
          { name = "GF_PATHS_PROVISIONING", value = "/var/lib/grafana/provisioning" },
          { name = "GF_SERVER_HTTP_PORT", value = tostring(var.grafana_port) },
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
        ],
        var.alb_enabled ? [
          { name = "GF_SERVER_ROOT_URL", value = "https://${var.hostname}/" },
          { name = "GF_SECURITY_COOKIE_SECURE", value = "true" },
        ] : []
      )

      secrets = [{
        name      = "GF_SECURITY_ADMIN_PASSWORD"
        valueFrom = "${aws_secretsmanager_secret.grafana.arn}:admin_password::"
      }]
    }

    # One-shot: creates / updates the pg_monitor role with the master credentials
    postgres-init = {
      image     = "postgres:18.6-alpine@sha256:9ba53c7d41ea093baf5c1ba635ba5434c4f979880527d49bb7d9237d3193085b"
      essential = false

      memoryReservation = 32
      restartPolicy     = { enabled = false }

      entrypoint = ["sh", "-c"]
      command    = [file("${path.module}/templates/postgres-init.sh")]

      cloudwatch_log_group_name = "${local.log_group_prefix}/postgres-init"

      environment = [
        { name = "PGHOST", value = var.db_address },
        { name = "PGPORT", value = tostring(var.db_port) },
        { name = "PGDATABASE", value = var.db_name },
        { name = "PGSSLMODE", value = "require" },
        { name = "PGCONNECT_TIMEOUT", value = "10" },
        { name = "PGAPPNAME", value = "monitoring-init" },
        { name = "MONITORING_USER", value = local.db_monitoring_user },
      ]

      secrets = [
        { name = "PGUSER", valueFrom = "${var.db_master_secret_arn}:username::" },
        { name = "PGPASSWORD", valueFrom = "${var.db_master_secret_arn}:password::" },
        { name = "MONITORING_PASSWORD", valueFrom = "${aws_secretsmanager_secret.db_monitoring.arn}:password::" },
      ]
    }

    postgres-exporter = {
      image     = "quay.io/prometheuscommunity/postgres-exporter:v0.20.1@sha256:ac5ec343104fae0e2d84a27bb8d69b38430a11910c5382cad85d478d2bab713e"
      essential = false

      memoryReservation = 64

      # Starts even if the init failed; pg_up = 0 then shows the problem
      dependsOn = [{ containerName = "postgres-init", condition = "COMPLETE" }]

      cloudwatch_log_group_name = "${local.log_group_prefix}/postgres-exporter"

      environment = [
        { name = "DATA_SOURCE_URI", value = "${var.db_address}:${var.db_port}/${var.db_name}?sslmode=require" },
        { name = "DATA_SOURCE_USER", value = local.db_monitoring_user },
      ]

      secrets = [{
        name      = "DATA_SOURCE_PASS"
        valueFrom = "${aws_secretsmanager_secret.db_monitoring.arn}:password::"
      }]
    }

    blackbox-exporter = {
      image     = "prom/blackbox-exporter:v0.29.1@sha256:ea1c7aa3ef3f307cd03e85f34abb604478ccb90b567fc690da0cd9776da76b13"
      essential = false

      memoryReservation = 32

      cloudwatch_log_group_name = "${local.log_group_prefix}/blackbox-exporter"
    }
  }

  # Docker volumes on the instance root volume; Docker copies the image directory (and
  # its owner) into a new volume, so Prometheus (nobody) and Grafana (472) can write
  volume = {
    prometheus-data = {
      docker_volume_configuration = {
        scope         = "shared"
        autoprovision = true
        driver        = "local"
      }
    }
    grafana-data = {
      docker_volume_configuration = {
        scope         = "shared"
        autoprovision = true
        driver        = "local"
      }
    }
  }

  load_balancer = var.alb_enabled ? {
    grafana = {
      target_group_arn = terraform_data.grafana_target_group[0].output
      container_name   = "grafana"
      container_port   = var.grafana_port
    }
  } : null
  health_check_grace_period_seconds = var.alb_enabled ? 120 : null

  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }

  # One instance, local volumes, memory for one task: stop the old task first
  deployment_maximum_percent         = 100
  deployment_minimum_healthy_percent = 0

  desired_count      = 1
  enable_autoscaling = false

  subnet_ids            = var.subnet_ids
  create_security_group = false
  security_group_ids    = [var.security_group_id]

  tags = {
    Name    = "${var.stage}-monitoring-service"
    Service = "monitoring"
  }
}
