module "grafana_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name            = "${var.stage}-grafana-sg"
  description     = "Security group for the Grafana task"
  vpc_id          = var.vpc_id
  use_name_prefix = false

  # No ingress (SSM only)

  egress_rules = merge(
    {
      https = {
        from_port   = 443
        to_port     = 443
        ip_protocol = "tcp"
        description = "CloudWatch API, SSM, Docker Hub and in-VPC endpoints"
        cidr_ipv4   = "0.0.0.0/0"
      }
    },
    var.efs_enabled ? {
      nfs = {
        from_port                    = 2049
        to_port                      = 2049
        ip_protocol                  = "tcp"
        description                  = "Grafana data on EFS"
        referenced_security_group_id = module.efs_sg.id
      }
    } : {}
  )

  tags = {
    Name    = "${var.stage}-grafana-sg"
    Service = "monitoring"
  }
}

module "efs_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  create = var.efs_enabled

  name            = "${var.stage}-grafana-efs-sg"
  description     = "Security group for the Grafana EFS mount target"
  vpc_id          = var.vpc_id
  use_name_prefix = false

  ingress_rules = {
    nfs = {
      from_port                    = 2049
      to_port                      = 2049
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.grafana_sg.id
    }
  }

  tags = {
    Name    = "${var.stage}-grafana-efs-sg"
    Service = "monitoring"
  }
}
