output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "nat_public_ip" {
  value = module.network.nat_public_ip
}

output "db_endpoint" {
  value = module.database.db_endpoint
}

output "db_proxy_endpoint" {
  value = module.database.db_proxy_endpoint
}

output "ecs_cluster_arn" {
  value = module.backend.cluster_arn
}

output "ecs_service_name" {
  value = module.backend.service_name
}

output "load_balancer_dns_name" {
  value = module.backend.load_balancer_dns_name
}

output "internal_load_balancer_dns_name" {
  value = module.backend.internal_load_balancer_dns_name
}

output "grafana_service_name" {
  value = one(module.monitoring[*].service_name)
}

output "grafana_admin_secret_arn" {
  value = one(module.monitoring[*].admin_secret_arn)
}
