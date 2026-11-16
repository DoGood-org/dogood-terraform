# Internet egress for the private subnets: fck-nat instance in the first public subnet.
# ha_mode keeps a static ENI, so the ASG replaces a failed instance without route changes.
module "nat" {
  source  = "RaJiska/fck-nat/aws"
  version = "~> 1.6"

  name          = "${var.stage}-nat"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnets[0]
  instance_type = var.nat_instance_type
  ha_mode       = true

  update_route_tables = true
  route_tables_ids = {
    for i in range(length(local.private_subnet_cidrs)) :
    "private-${i + 1}" => module.vpc.private_route_table_ids[i]
  }

  tags = {
    Name    = "${var.stage}-nat"
    Service = "networking"
  }
}
