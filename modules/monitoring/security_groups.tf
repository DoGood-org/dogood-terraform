module "grafana_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name            = "${var.stage}-grafana-sg"
  description     = "Security group for the Grafana task"
  vpc_id          = var.vpc_id
  use_name_prefix = false

  # No ingress: Grafana is reached only through an SSM port-forwarding session,
  # which the in-task agent opens outbound.

  egress_rules = {
    https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "CloudWatch API, SSM, Docker Hub and in-VPC endpoints"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = {
    Name    = "${var.stage}-grafana-sg"
    Service = "monitoring"
  }
}
