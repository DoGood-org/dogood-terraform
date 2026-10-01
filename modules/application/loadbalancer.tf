module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.0"

  name    = "${var.stage}-app-lb"
  vpc_id  = var.vpc_id
  subnets = var.public_subnet_ids

  internal              = false
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
      name              = "${var.stage}-app-tg"
      protocol          = "HTTP"
      port              = var.container_port
      target_type       = "ip"
      create_attachment = false

      tags = merge(local.default_tags, {
        Name    = "${var.stage}-app-tg"
        Service = "application"
      })
    }
  }

  tags = merge(local.default_tags, {
    Name    = "${var.stage}-app-lb"
    Service = "application"
  })
}
