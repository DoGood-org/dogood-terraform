output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "db_endpoint" {
  value = module.database.db_endpoint
}

output "ecs_cluster_arn" {
  value = module.application.cluster_arn
}

output "ecs_service_name" {
  value = module.application.service_name
}

output "load_balancer_dns_name" {
  value = module.application.load_balancer_dns_name
}

output "grafana_service_name" {
  value = one(module.monitoring[*].service_name)
}

output "grafana_admin_secret_arn" {
  value = one(module.monitoring[*].admin_secret_arn)
}

