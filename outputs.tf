output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}

output "db_endpoint" {
  value = module.database.db_endpoint
}

output "ecs_cluster_id" {
  value = module.application.cluster_id
}

output "ecs_service_name" {
  value = module.application.service_name
}

output "load_balancer_dns_name" {
  value = module.application.load_balancer_dns_name
}