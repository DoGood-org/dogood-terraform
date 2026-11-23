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

  # Public ALB with TLS: 80 redirects to 443; on 443 api_hostname goes to the app and any
  # other host gets 404 (the monitoring module adds its own rules for monitoring_hostname).
  # Internal ALB, or no hostnames set: plain HTTP on 80 and 443, everything to the app.
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = each.key == "public" && local.https_enabled ? null : {
        target_group_key = "app"
      }
      redirect = each.key == "public" && local.https_enabled ? {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      } : null
    }
    https = {
      port            = 443
      protocol        = each.key == "public" && local.https_enabled ? "HTTPS" : "HTTP"
      certificate_arn = each.key == "public" && local.https_enabled ? aws_acm_certificate_validation.this[0].certificate_arn : null
      ssl_policy      = each.key == "public" && local.https_enabled ? "ELBSecurityPolicy-TLS13-1-2-2021-06" : null

      forward = each.key == "public" && local.host_routing ? null : {
        target_group_key = "app"
      }
      fixed_response = each.key == "public" && local.host_routing ? {
        content_type = "text/plain"
        message_body = "Not found"
        status_code  = "404"
      } : null

      rules = {
        for key, rule in {
          api = {
            priority = 100
            actions  = [{ forward = { target_group_key = "app" } }]
            conditions = [{
              host_header = { values = [var.api_hostname] }
            }]
          }
        } : key => rule if each.key == "public" && local.host_routing
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
