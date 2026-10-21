module "network" {
  source = "./modules/networking"

  stage                   = var.stage
  vpc_cidr_block          = var.vpc_cidr_block
  db_port                 = var.db_port
  app_port                = var.app_port
  vpc_endpoints_single_az = var.vpc_endpoints_single_az
}

module "database" {
  source = "./modules/database"

  stage                = var.stage
  db_name              = var.app_secrets["POSTGRES_DB"]
  db_username          = var.app_secrets["POSTGRES_USER"]
  db_instance_class    = var.db_instance_class
  db_port              = var.db_port
  deletion_protection  = var.db_deletion_protection
  skip_final_snapshot  = var.db_skip_final_snapshot
  multi_az             = var.db_multi_az
  availability_zone    = module.network.azs[0]
  read_replica_count   = var.db_read_replica_count
  db_subnet_group_name = module.network.db_subnet_group_name
  db_security_group_id = module.network.db_security_group_id
}

module "application" {
  source = "./modules/application"

  stage                       = var.stage
  app_secrets                 = var.app_secrets
  secret_recovery_window_days = var.app_secret_recovery_window_days
  public_subnet_ids           = module.network.public_subnet_ids
  private_subnet_ids          = module.network.private_subnet_ids
  vpc_id                      = module.network.vpc_id
  instance_sg_id              = module.network.instance_security_group_id
  alb_sg_id                   = module.network.alb_security_group_id
  db_address                  = module.database.db_address
  db_port                     = module.database.db_port
  db_master_secret_arn        = module.database.db_master_secret_arn
  single_az                   = var.ecs_single_az
  task_cpu                    = var.ecs_task_cpu
  task_memory                 = var.ecs_task_memory
  min_capacity                = var.ecs_min_capacity
  max_capacity                = var.ecs_max_capacity
  container_port              = var.app_port
  health_check_path           = var.app_health_check_path
  container_image             = "${data.aws_ecr_repository.backend.repository_url}:latest"
  ecr_repository_arn          = data.aws_ecr_repository.backend.arn
}

module "monitoring" {
  source = "./modules/monitoring"
  count  = var.monitoring_enabled ? 1 : 0

  stage       = var.stage
  vpc_id      = module.network.vpc_id
  subnet_id   = module.network.public_subnet_ids[0]
  cluster_arn = module.application.cluster_arn
  efs_enabled = var.grafana_efs_enabled
}

