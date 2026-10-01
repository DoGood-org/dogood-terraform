module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 6.0"

  name = "${var.stage}-vpc"
  cidr = var.vpc_cidr_block

  azs             = local.azs
  public_subnets  = local.public_subnet_cidrs
  private_subnets = local.private_subnet_cidrs

  public_subnet_names  = [for i in range(length(local.public_subnet_cidrs)) : "${var.stage}-public-subnet-${i + 1}"]
  private_subnet_names = [for i in range(length(local.private_subnet_cidrs)) : "${var.stage}-private-subnet-${i + 1}"]

  create_igw = true

  # No NAT gateway: private subnets rely on VPC interface endpoints for AWS
  # service access, matching the original hand-written configuration.
  enable_nat_gateway = false

  create_database_subnet_group = false

  manage_default_security_group = false

  igw_tags = merge(local.default_tags, {
    Name    = "${var.stage}-igw"
    Service = "networking"
  })

  public_route_table_tags = merge(local.default_tags, {
    Name    = "${var.stage}-public-route-table"
    Service = "networking"
  })

  private_route_table_tags = merge(local.default_tags, {
    Name    = "${var.stage}-private-route-table"
    Service = "networking"
  })

  tags = local.default_tags
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.stage}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = merge(local.default_tags, {
    Name    = "${var.stage}-db-subnet-group"
    Service = "networking"
  })
}
