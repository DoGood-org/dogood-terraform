locals {
  infra_managed_env_keys = ["PORT", "POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_USER", "POSTGRES_PASSWORD", "DATABASE_URL"]

  log_group_name = "/aws/ecs/${var.stage}/dogood-backend"
  log_group_arn  = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}"

  ecs_exporter_log_group_name = "${local.log_group_name}-ecs-exporter"
  ecs_exporter_log_group_arn  = "${local.log_group_arn}-ecs-exporter"

  task_subnet_ids = var.single_az ? slice(var.private_subnet_ids, 0, 1) : var.private_subnet_ids
}

# Ordering barriers. The ECS module creates task definitions create_before_destroy, and
# Terraform forces that onto everything they depend on. Keeping the ALB out of the task
# definition's dependencies lets the ALB be replaced destroy-first (a target group can
# belong to only one ALB, and the name is reused).

# Task definition: execution role with its policy and the app secret
resource "terraform_data" "service_prerequisites" {
  input = aws_iam_role.ecs_execution.arn

  depends_on = [aws_iam_role_policy.ecs_execution, aws_secretsmanager_secret_version.app_env]
}

# Service: the target group must be attached to a listener before the service registers tasks
resource "terraform_data" "target_group" {
  input = { for key, alb in module.alb : key => alb.target_groups["app"].arn }

  depends_on = [module.alb]
}

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 7.0"

  name = "${var.stage}-cluster"

  # Container Insights off
  create_cloudwatch_log_group = false
  configuration               = null
  setting                     = []
  create_security_group       = false

  tags = {
    Name    = "${var.stage}-cluster"
    Service = "backend"
  }
}

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 7.0"

  name        = "dogood-backend"
  family      = "${var.stage}-dogood-backend"
  cluster_arn = module.ecs_cluster.arn

  cpu    = var.task_cpu
  memory = var.task_memory

  create_task_exec_iam_role = false
  create_task_exec_policy   = false
  task_exec_iam_role_arn    = terraform_data.service_prerequisites.output

  create_iam_role       = false
  create_tasks_iam_role = false

  container_definitions = merge({
    dogood-backend = {
      image     = var.container_image
      essential = true

      entrypoint             = ["sh", "-c"]
      command                = [file("${path.module}/templates/start.sh")]
      readonlyRootFilesystem = false

      cloudwatch_log_group_name = local.log_group_name

      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]

      environment = [
        { name = "PORT", value = tostring(var.container_port) },
        { name = "POSTGRES_HOST", value = var.db_address },
        { name = "POSTGRES_PORT", value = tostring(var.db_port) },
      ]

      secrets = concat(
        [
          for key, value in var.app_secrets : {
            name      = key
            valueFrom = "${aws_secretsmanager_secret.app_env.arn}:${key}::"
          } if !contains(local.infra_managed_env_keys, key) && nonsensitive(value != "")
        ],
        [
          {
            name      = "POSTGRES_USER"
            valueFrom = "${var.db_master_secret_arn}:username::"
          },
          {
            name      = "POSTGRES_PASSWORD"
            valueFrom = "${var.db_master_secret_arn}:password::"
          },
        ]
      )
    }
    },
    # Task CPU/memory/network metrics from the task metadata endpoint, scraped by Prometheus
    {
      for name, container in {
        ecs-exporter = {
          image     = "quay.io/prometheuscommunity/ecs-exporter:v0.6.0@sha256:03674eb4275510af0ae8d69644dfce7532a41e80171cffdd65186aa57ff52bcc"
          essential = false

          cloudwatch_log_group_name = local.ecs_exporter_log_group_name

          portMappings = [{
            containerPort = var.ecs_exporter_port
            hostPort      = var.ecs_exporter_port
            protocol      = "tcp"
          }]
        }
      } : name => container if var.ecs_exporter_enabled
    }
  )

  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }

  desired_count                     = var.min_capacity
  health_check_grace_period_seconds = 60

  enable_autoscaling       = true
  autoscaling_min_capacity = var.min_capacity
  autoscaling_max_capacity = var.max_capacity

  # Same keys as the module defaults, so existing policies are updated, not replaced
  autoscaling_policies = {
    cpu = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageCPUUtilization"
        }
        target_value = var.autoscaling_target_cpu_utilization
      }
    }
    memory = {
      policy_type = "TargetTrackingScaling"
      target_tracking_scaling_policy_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ECSServiceAverageMemoryUtilization"
        }
      }
    }
  }

  ignore_task_definition_changes = true

  subnet_ids            = local.task_subnet_ids
  create_security_group = false
  security_group_ids    = [var.instance_sg_id]

  # Tasks register in the target group of every enabled ALB
  load_balancer = {
    for key in keys(local.albs) : key => {
      target_group_arn = terraform_data.target_group.output[key]
      container_name   = "dogood-backend"
      container_port   = var.container_port
    }
  }

  tags = {
    Name    = "${var.stage}-dogood-backend-service"
    Service = "backend"
  }
}
