locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnet_cidrs  = [for i in range(2) : cidrsubnet(var.vpc_cidr_block, 8, (i + 10) * 10)]
  private_subnet_cidrs = [for i in range(2) : cidrsubnet(var.vpc_cidr_block, 8, (i + 1) * 10)]
}
