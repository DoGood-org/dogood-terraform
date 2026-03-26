provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}



module "network" {
  source = "./modules/networking"

  stage          = var.stage
  vpc_cidr_block = var.vpc_cidr_block
  my_ip          = var.my_ip
  db_port        = var.db_port
}

module "database" {
  source = "./modules/database"

  stage                = var.stage
  app_secrets          = var.app_secrets
  db_instance_class    = var.db_instance_class
  db_subnet_group_name = module.network.db_subnet_group_name
  db_security_group_id = module.network.db_security_group_id
}

module "application" {
  source = "./modules/application"

  stage               = var.stage
  instance_type       = var.instance_type
  ssh_key_path        = var.ssh_key_path
  app_secrets         = var.app_secrets
  public_subnet_ids   = module.network.public_subnet_ids
  private_subnet_ids  = module.network.private_subnet_ids
  vpc_id              = module.network.vpc_id
  alb_sg_id           = module.network.alb_sg_id
  instance_sg_id      = module.network.instance_sg_id
  db_endpoint         = module.database.db_endpoint
}

module "proxy" {
  source = "./modules/proxy"

  stage           = var.stage
  ami_id          = var.ami_id
  instance_type    = var.instance_type
  ssh_key_path     = var.ssh_key_path
  subnet_id        = module.network.public_subnet_ids[0]
  security_groups  = [module.network.instance_sg_id]
  ssh_key          = module.application.ssh_key
}