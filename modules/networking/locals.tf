locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnet_cidrs  = [for i in range(2) : cidrsubnet(var.vpc_cidr_block, 8, (i + 10) * 10)]
  private_subnet_cidrs = [for i in range(2) : cidrsubnet(var.vpc_cidr_block, 8, (i + 1) * 10)]

  endpoint_subnet_ids = var.vpc_endpoints_single_az ? slice(module.vpc.private_subnets, 0, 1) : module.vpc.private_subnets
}
