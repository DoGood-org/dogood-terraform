resource "aws_key_pair" "ssh_key" {
  key_name   = "${var.stage}_deploy_key"
  public_key = file(var.ssh_key_path)
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.stage}-ec2-ecr-profile"
  role = data.aws_iam_role.ec2_role.name
}

resource "aws_ecs_cluster" "main" {
  name = "${var.stage}-cluster"
}

resource "aws_launch_template" "app_launch_template" {
  name_prefix   = "${var.stage}-app-lt-"
  image_id      = data.aws_ssm_parameter.ecs_optimized_ami.value
  instance_type = var.instance_type

  key_name = aws_key_pair.ssh_key.key_name
  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = base64encode(<<-EOF
      #!/bin/bash
      echo ECS_CLUSTER=${aws_ecs_cluster.main.name} > /etc/ecs/ecs.config
    EOF
  )

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.instance_sg_id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.stage}-app-instance"
    }
  }
}

resource "aws_autoscaling_group" "ecs" {
  name                      = "${var.stage}-app-asg"
  max_size                  = 3
  min_size                  = 1
  desired_capacity          = 1
  vpc_zone_identifier       = var.public_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.stage}-app-asg-instance"
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "ec2" {
  name = "${var.stage}-ec2-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.ecs.arn
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name       = aws_ecs_cluster.main.name
  capacity_providers = [aws_ecs_capacity_provider.ec2.name]
}

resource "aws_lb" "app_lb" {
  name               = "${var.stage}-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.instance_sg_id]
  subnets            = var.public_subnet_ids

  tags = {
    Name = "${var.stage}-app-lb"
  }
}

resource "aws_lb_target_group" "app_tg" {
  name        = "${var.stage}-app-tg"
  port        = var.container_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id
}

resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = var.container_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

resource "aws_secretsmanager_secret" "app_env" {
  name                    = "/dogood/${var.stage}/env"
  description             = "App environment variables"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "app_env" {
  secret_id     = aws_secretsmanager_secret.app_env.id
  secret_string = jsonencode(local.app_secrets_with_db_url)
}

resource "aws_ecs_task_definition" "app" {
  family                   = "dogood-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name  = "dogood-backend"
    image = var.container_image
    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.container_port
      protocol      = "tcp"
    }]
    secrets = [
      for key in keys(local.app_secrets_with_db_url) : {
        name      = key
        valueFrom = "${aws_secretsmanager_secret.app_env.arn}:${key}::"
      }
    ]
  }])
}

resource "aws_ecs_service" "app" {
  name            = "dogood-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1

  network_configuration {
    subnets         = var.public_subnet_ids
    security_groups = [var.instance_sg_id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "dogood-backend"
    container_port   = var.container_port
  }

  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.ec2.name
    weight            = 1
  }

  depends_on = [aws_lb_listener.app_listener]
}

resource "aws_autoscaling_policy" "scale_up_policy" {
  name                   = "${var.stage}-scale-up-policy"
  autoscaling_group_name = aws_autoscaling_group.ecs.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}
