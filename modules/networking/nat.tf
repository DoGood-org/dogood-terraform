# Internet egress for the private subnets: fck-nat instances in the public subnets.
# nat_per_az = true: one instance per AZ, each private route table points at the instance in
# its own AZ. false: one instance in the first AZ for both route tables.
# ha_mode keeps a static ENI, so the ASG replaces a failed instance without route changes.
locals {
  nat_count = var.nat_per_az ? length(local.azs) : 1
  nat_arch  = can(regex("[a-zA-Z]+\\d+g[a-z]*\\..+", var.nat_instance_type)) ? "arm64" : "amd64"

  # Prometheus node_exporter (scraped by the monitoring stack); release checksums pinned
  node_exporter_version = "1.12.1"
  node_exporter_sha256 = {
    arm64 = "ad35b605f9954b9f1ffddf5ba054bdc5a98d790b9eae5291e1eeb83f1ecbd0e7"
    amd64 = "b51d8a76aa2a9156a55d501aca6276fae09e262259a5e4e831d2c2222f084e63"
  }
}

moved {
  from = module.nat
  to   = module.nat[0]
}

module "nat" {
  source  = "RaJiska/fck-nat/aws"
  version = "~> 1.6"

  count = local.nat_count

  # The first instance keeps its original name, so switching nat_per_az doesn't replace it
  name          = count.index == 0 ? "${var.stage}-nat" : "${var.stage}-nat-${count.index + 1}"
  vpc_id        = module.vpc.vpc_id
  subnet_id     = module.vpc.public_subnets[count.index]
  instance_type = var.nat_instance_type
  ha_mode       = true

  update_route_tables = true
  route_tables_ids = {
    for i in range(length(local.private_subnet_cidrs)) :
    "private-${i + 1}" => module.vpc.private_route_table_ids[i]
    if !var.nat_per_az || i == count.index
  }

  cloud_init_parts = var.node_exporter_enabled ? [{
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/node_exporter.sh", {
      version = local.node_exporter_version
      arch    = local.nat_arch
      sha256  = local.node_exporter_sha256[local.nat_arch]
      port    = var.node_exporter_port
    })
  }] : []

  tags = {
    Name    = count.index == 0 ? "${var.stage}-nat" : "${var.stage}-nat-${count.index + 1}"
    Service = "networking"
  }
}
