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

  egress_rules = {
    all = {
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

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

  ingress_rules = {
    from_instances = {
      from_port                    = var.db_port
      to_port                      = var.db_port
      ip_protocol                  = "tcp"
      referenced_security_group_id = module.instance_sg.id
    }
  }

  tags = {
    Name    = "${var.stage}-db-sg"
    Service = "networking"
  }
}

module "vpc_endpoints_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 6.0"

  name            = "${var.stage}-vpc-endpoints-sg"
  description     = "Security group for VPC interface endpoints"
  vpc_id          = module.vpc.vpc_id
  use_name_prefix = false

  ingress_rules = {
    https = {
      from_port   = 443
      to_port     = 443
      ip_protocol = "tcp"
      cidr_ipv4   = var.vpc_cidr_block
    }
  }

  # Interface endpoint ENIs only answer inbound HTTPS requests from the VPC;
  # they never initiate outbound connections, so no egress is required.

  tags = {
    Name    = "${var.stage}-vpc-endpoints-sg"
    Service = "networking"
  }
}
