# S3 gateway (free): ECR image layers bypass the NAT instance
module "vpc_endpoints" {
  source  = "terraform-aws-modules/vpc/aws//modules/vpc-endpoints"
  version = "~> 6.0"

  vpc_id = module.vpc.vpc_id

  endpoints = {
    s3 = {
      service         = "s3"
      service_type    = "Gateway"
      route_table_ids = module.vpc.private_route_table_ids
      tags = {
        Name    = "${var.stage}-s3-endpoint"
        Service = "networking"
      }
    }
  }
}
