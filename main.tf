locals {
  # Fixed ports of the monitoring components
  ecs_exporter_port  = 9779
  node_exporter_port = 9100
  grafana_port       = 3000
}

module "network" {
  source = "./modules/networking"

  stage             = var.stage
  vpc_cidr_block    = var.vpc_cidr_block
  db_port           = var.db_port
  app_port          = var.app_port
  nat_instance_type = var.nat_instance_type
  app_egress_ports  = var.app_egress_ports
  db_proxy_enabled  = var.db_proxy_enabled
  nat_per_az        = var.nat_per_az

  monitoring_enabled    = var.monitoring_enabled
  node_exporter_enabled = var.monitoring_enabled
  node_exporter_port    = local.node_exporter_port
  ecs_exporter_port     = local.ecs_exporter_port
  grafana_port          = local.grafana_port
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
  apply_immediately    = var.db_apply_immediately
  db_subnet_group_name = module.network.db_subnet_group_name
  db_security_group_id = module.network.db_security_group_id

  proxy_enabled           = var.db_proxy_enabled
  proxy_subnet_ids        = module.network.private_subnet_ids
  proxy_security_group_id = module.network.db_proxy_security_group_id
}

module "backend" {
  source = "./modules/backend"

  stage                              = var.stage
  app_secrets                        = var.app_secrets
  secret_recovery_window_days        = var.app_secret_recovery_window_days
  public_subnet_ids                  = module.network.public_subnet_ids
  private_subnet_ids                 = module.network.private_subnet_ids
  vpc_id                             = module.network.vpc_id
  instance_sg_id                     = module.network.instance_security_group_id
  alb_sg_id                          = module.network.alb_security_group_id
  db_address                         = module.database.client_address
  db_port                            = module.database.db_port
  db_master_secret_arn               = module.database.db_master_secret_arn
  single_az                          = var.ecs_single_az
  task_cpu                           = var.ecs_task_cpu
  task_memory                        = var.ecs_task_memory
  min_capacity                       = var.ecs_min_capacity
  max_capacity                       = var.ecs_max_capacity
  autoscaling_target_cpu_utilization = var.ecs_autoscaling_target_cpu_utilization
  container_port                     = var.app_port
  health_check_path                  = var.app_health_check_path
  public_alb_enabled                 = var.alb_public_enabled
  internal_alb_enabled               = var.alb_internal_enabled
  container_image                    = "${data.aws_ecr_repository.backend.repository_url}:e6000713ebc4e05d27f9add29788fecc719df343"
  ecr_repository_arn                 = data.aws_ecr_repository.backend.arn
  tls_hostnames                      = var.api_hostname == null ? [] : compact([var.api_hostname, var.monitoring_hostname])
  api_hostname                       = var.api_hostname
  ecs_exporter_enabled               = var.monitoring_enabled
  ecs_exporter_port                  = local.ecs_exporter_port
}

module "monitoring" {
  source = "./modules/monitoring"
  count  = var.monitoring_enabled ? 1 : 0

  stage             = var.stage
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.monitoring_security_group_id

  instance_type             = var.monitoring_instance_type
  volume_size               = var.monitoring_volume_size
  prometheus_retention_time = var.prometheus_retention_time
  prometheus_retention_size = var.prometheus_retention_size

  backend_cluster_arn  = module.backend.cluster_arn
  backend_service_name = module.backend.service_name
  app_port             = var.app_port
  backend_metrics_path = var.backend_metrics_path
  ecs_exporter_port    = local.ecs_exporter_port
  node_exporter_port   = local.node_exporter_port
  grafana_port         = local.grafana_port
  probe_url            = var.api_hostname == null ? null : "https://${var.api_hostname}${var.app_health_check_path}"

  db_address           = module.database.db_address
  db_port              = module.database.db_port
  db_name              = var.app_secrets["POSTGRES_DB"]
  db_master_secret_arn = module.database.db_master_secret_arn

  alb_enabled        = var.monitoring_hostname != null
  https_listener_arn = module.backend.https_listener_arn
  hostname           = var.monitoring_hostname
  allowed_cidrs      = var.monitoring_allowed_cidrs
}
