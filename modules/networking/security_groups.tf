module "alb_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name            = "${var.stage}-alb-sg"
  description     = "Security group for public application load balancer"
  vpc_id          = module.vpc.vpc_id
  use_name_prefix = false

  ingress_rules = {
    http = {
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
    https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  egress_rules = {
    app_port = {
      from_port                    = var.app_port
      to_port                      = var.app_port
      ip_protocol                  = "tcp"
      description                  = "To ECS tasks only"
      referenced_security_group_id = module.instance_sg.id
    }
  }

  tags = {
    Name    = "${var.stage}-alb-sg"
    Service = "networking"
  }
}

module "instance_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name            = "${var.stage}-instance-sg"
  description     = "Security group for ECS tasks"
  vpc_id          = module.vpc.vpc_id
  use_name_prefix = false

  ingress_rules = {
    app_port = {
      from_port                    = var.app_port
      to_port                      = var.app_port
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.alb_sg.id
    }
  }

  egress_rules = merge(
    {
      db = {
        from_port                    = var.db_port
        to_port                      = var.db_port
        ip_protocol                  = "tcp"
        description                  = "RDS"
        referenced_security_group_id = module.db_sg.id
      }
    },
    # AWS APIs (ECR, CloudWatch Logs, Secrets Manager) and third-party services via NAT
    {
      for port in var.app_egress_ports : "internet_${port}" => {
        from_port   = port
        to_port     = port
        ip_protocol = "tcp"
        description = "Internet via NAT"
        cidr_ipv4   = "0.0.0.0/0"
      }
    },
    var.db_proxy_enabled ? {
      db_proxy = {
        from_port                    = var.db_port
        to_port                      = var.db_port
        ip_protocol                  = "tcp"
        description                  = "RDS Proxy"
        referenced_security_group_id = module.db_proxy_sg.id
      }
    } : {}
  )

  tags = {
    Name    = "${var.stage}-instance-sg"
    Service = "networking"
  }
}

module "db_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name            = "${var.stage}-db-sg"
  description     = "Security group for the RDS instance"
  vpc_id          = module.vpc.vpc_id
  use_name_prefix = false

  ingress_rules = merge(
    {
      from_instances = {
        from_port                    = var.db_port
        to_port                      = var.db_port
        ip_protocol                  = "tcp"
        referenced_security_group_id = module.instance_sg.id
      }
    },
    var.db_proxy_enabled ? {
      from_db_proxy = {
        from_port                    = var.db_port
        to_port                      = var.db_port
        ip_protocol                  = "tcp"
        referenced_security_group_id = module.db_proxy_sg.id
      }
    } : {}
  )

  tags = {
    Name    = "${var.stage}-db-sg"
    Service = "networking"
  }
}

module "db_proxy_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  create = var.db_proxy_enabled

  name            = "${var.stage}-db-proxy-sg"
  description     = "Security group for the RDS Proxy"
  vpc_id          = module.vpc.vpc_id
  use_name_prefix = false

  ingress_rules = {
    from_instances = {
      from_port                    = var.db_port
      to_port                      = var.db_port
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.instance_sg.id
    }
  }

  egress_rules = {
    db = {
      from_port                    = var.db_port
      to_port                      = var.db_port
      ip_protocol                  = "tcp"
      description                  = "RDS"
      referenced_security_group_id = module.db_sg.id
    }
    secretsmanager = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      description = "Secrets Manager via NAT (DB credentials)"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  tags = {
    Name    = "${var.stage}-db-proxy-sg"
    Service = "networking"
  }
}
