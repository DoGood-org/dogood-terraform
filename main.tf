provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "network" {
  source = "./modules/networking"

  stage          = var.stage
  vpc_cidr_block = var.vpc_cidr_block
  db_port        = var.db_port
}

module "database" {
  source = "./modules/database"

  stage                = var.stage
  app_secrets          = var.app_secrets
  db_instance_class    = var.db_instance_class
  db_subnet_group_name = module.network.db_subnet_group_name
  db_security_group_id = module.network.db_security_group_id
  private_subnet_ids   = module.network.private_subnet_ids
}

module "application" {
  source = "./modules/application"

  stage              = var.stage
  app_secrets        = var.app_secrets
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  vpc_id             = module.network.vpc_id
  instance_sg_id     = module.network.instance_security_group_id
  alb_sg_id          = module.network.alb_security_group_id
  container_image    = "${data.aws_ecr_repository.backend.repository_url}:latest"
  depends_on         = [module.database]
}

module "cloudflare" {
  source = "./modules/cloudflare"

  zone_id   = var.cloudflare_zone_id
  subdomain = var.stage
  target    = module.application.load_balancer_dns_name
}