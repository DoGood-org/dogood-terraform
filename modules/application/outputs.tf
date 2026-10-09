output "cluster_id" {
  value = module.ecs_cluster.id
}

output "service_name" {
  value = module.ecs_service.name
}

output "load_balancer_dns_name" {
  value = module.alb.dns_name
}
