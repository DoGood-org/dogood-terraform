module "ecs_cluster" {
  source  = "terraform-aws-modules/ecs/aws//modules/cluster"
  version = "~> 7.0"

  name = "${var.stage}-cluster"

  create_cloudwatch_log_group = false
  configuration               = null
  setting                     = []
  create_security_group       = false

  tags = merge(local.default_tags, {
    Name    = "${var.stage}-cluster"
    Service = "application"
  })
}

module "ecs_service" {
  source  = "terraform-aws-modules/ecs/aws//modules/service"
  version = "~> 7.0"

  name        = "dogood-backend"
  family      = "dogood-backend"
  cluster_arn = module.ecs_cluster.arn

  cpu    = 256
  memory = 512

  requires_compatibilities = ["FARGATE"]
  launch_type              = "FARGATE"
  network_mode             = "awsvpc"

  create_task_exec_iam_role = false
  create_task_exec_policy   = false
  task_exec_iam_role_arn    = data.aws_iam_role.ecs_execution_role.arn

  create_iam_role       = false
  create_tasks_iam_role = false

  container_definitions = {
    dogood-backend = {
      image     = var.container_image
      essential = true

      entryPoint        = var.container_entrypoint
      cpu               = var.container_cpu
      memoryReservation = var.container_memory_reservation

      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.container_port
        protocol      = "tcp"
      }]

      secrets = [
        for key in keys(var.app_secrets) : {
          name      = key
          valueFrom = "${aws_secretsmanager_secret.app_env.arn}:${key}::"
        }
      ]
    }
  }

  enable_autoscaling       = true
  autoscaling_min_capacity = 1
  autoscaling_max_capacity = 1

  ignore_task_definition_changes = true

  subnet_ids            = var.private_subnet_ids
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


  depends_on = [module.alb]

  tags = merge(local.default_tags, {
    Name    = "${var.stage}-dogood-backend-service"
    Service = "application"
  })
}
