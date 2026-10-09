locals {
  infra_managed_env_keys = ["PORT", "POSTGRES_HOST", "POSTGRES_PORT", "POSTGRES_USER", "POSTGRES_PASSWORD", "DATABASE_URL"]

  log_group_name = "/aws/ecs/${var.stage}/dogood-backend"
  log_group_arn  = "arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:${local.log_group_name}"

  task_subnet_ids = var.single_az ? slice(var.private_subnet_ids, 0, 1) : var.private_subnet_ids
}

module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 7.0"

  name = "${var.stage}-cluster"

  create_cloudwatch_log_group = false
  configuration               = null
  setting                     = []
  create_security_group       = false

  tags = {
    Name    = "${var.stage}-cluster"
    Service = "application"
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

  requires_compatibilities = ["FARGATE"]
  launch_type              = "FARGATE"
  network_mode             = "awsvpc"

  create_task_exec_iam_role = false
  create_task_exec_policy   = false
  task_exec_iam_role_arn    = aws_iam_role.ecs_execution.arn

  create_iam_role       = false
  create_tasks_iam_role = false

  container_definitions = {
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
  }

  deployment_circuit_breaker = {
    enable   = true
    rollback = true
  }

  desired_count                     = var.min_capacity
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  enable_autoscaling       = true
  autoscaling_min_capacity = var.min_capacity
  autoscaling_max_capacity = var.max_capacity

  ignore_task_definition_changes = true

  subnet_ids            = local.task_subnet_ids
  create_security_group = false
  security_group_ids    = [var.instance_sg_id]
  assign_public_ip      = false

  load_balancer = {
    service = {
      target_group_arn = module.alb.target_groups["app"].arn
      container_name   = "dogood-backend"
      container_port   = var.container_port
    }
  }


  depends_on = [module.alb, aws_iam_role_policy.ecs_execution, aws_secretsmanager_secret_version.app_env]

  tags = {
    Name    = "${var.stage}-dogood-backend-service"
    Service = "application"
  }
}
