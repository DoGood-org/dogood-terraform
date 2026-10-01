module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 6.0"

  vpc_id             = module.vpc.vpc_id
  security_group_ids = [module.vpc_endpoints_sg.id]

  endpoints = {
    ecr_dkr = {
      service             = "ecr.dkr"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags = {
        Name    = "${var.stage}-ecr-dkr-endpoint"
        Service = "networking"
      }
    }
    ecr_api = {
      service             = "ecr.api"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags = {
        Name    = "${var.stage}-ecr-api-endpoint"
        Service = "networking"
      }
    }
    logs = {
      service             = "logs"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags = {
        Name    = "${var.stage}-logs-endpoint"
        Service = "networking"
      }
    }
    secretsmanager = {
      service             = "secretsmanager"
      private_dns_enabled = true
      subnet_ids          = module.vpc.private_subnets
      tags = {
        Name    = "${var.stage}-secretsmanager-endpoint"
        Service = "networking"
      }
    }
  }
}
