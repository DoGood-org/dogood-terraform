# Grafana on the public ALB HTTPS listener: host = monitoring.* AND source IP in the
# allowlist -> Grafana; same host from anywhere else -> 403.

resource "aws_lb_target_group" "grafana" {
  count = var.alb_enabled ? 1 : 0

  name                 = "${var.stage}-grafana-tg"
  vpc_id               = var.vpc_id
  port                 = var.grafana_port
  protocol             = "HTTP"
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    enabled             = true
    path                = "/api/health"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name    = "${var.stage}-grafana-tg"
    Service = "monitoring"
  }
}

resource "aws_lb_listener_rule" "grafana_allow" {
  count = var.alb_enabled ? 1 : 0

  listener_arn = var.https_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana[0].arn
  }

  condition {
    host_header {
      values = [var.hostname]
    }
  }

  condition {
    source_ip {
      values = var.allowed_cidrs
    }
  }

  tags = {
    Name    = "${var.stage}-grafana-allow"
    Service = "monitoring"
  }
}

resource "aws_lb_listener_rule" "grafana_deny" {
  count = var.alb_enabled ? 1 : 0

  listener_arn = var.https_listener_arn
  priority     = 11

  action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Forbidden"
      status_code  = "403"
    }
  }

  condition {
    host_header {
      values = [var.hostname]
    }
  }

  tags = {
    Name    = "${var.stage}-grafana-deny"
    Service = "monitoring"
  }
}

# The target group must be attached to a listener before the service registers tasks
resource "terraform_data" "grafana_target_group" {
  count = var.alb_enabled ? 1 : 0

  input = aws_lb_target_group.grafana[0].arn

  depends_on = [aws_lb_listener_rule.grafana_allow]
}
