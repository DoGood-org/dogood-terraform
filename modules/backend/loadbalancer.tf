locals {
  # Public ALB in the public subnets, internal ALB in the private subnets.
  # A target group can belong to one ALB only, so each ALB has its own.
  albs = {
    for key, cfg in {
      public = {
        enabled  = var.public_alb_enabled
        internal = false
        subnets  = var.public_subnet_ids
        prefix   = "${var.stage}-app"
      }
      internal = {
        enabled  = var.internal_alb_enabled
        internal = true
        subnets  = var.private_subnet_ids
        prefix   = "${var.stage}-int"
      }
    } : key => cfg if cfg.enabled
  }
}

# Single ALB before both toggles existed
moved {
  from = module.alb
  to   = module.alb["public"]
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  for_each = local.albs

  name    = "${each.value.prefix}-lb"
  vpc_id  = var.vpc_id
  subnets = each.value.subnets

  internal              = each.value.internal
  load_balancer_type    = "application"
  security_groups       = [var.alb_sg_id]
  create_security_group = false

  enable_deletion_protection = false

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "app"
      }
    }
    https = {
      port     = 443
      protocol = "HTTP"

      forward = {
        target_group_key = "app"
      }
    }
  }

  target_groups = {
    app = {
      name              = "${each.value.prefix}-tg"
      protocol          = "HTTP"
      port              = var.container_port
      target_type       = "ip"
      create_attachment = false

      health_check = {
        enabled             = true
        path                = var.health_check_path
        matcher             = "200"
        interval            = 30
        timeout             = 5
        healthy_threshold   = 2
        unhealthy_threshold = 3
      }

      tags = {
        Name    = "${each.value.prefix}-tg"
        Service = "backend"
      }
    }
  }

  tags = {
    Name    = "${each.value.prefix}-lb"
    Service = "backend"
  }
}
