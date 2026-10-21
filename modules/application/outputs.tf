output "cluster_arn" {
  value = module.ecs_cluster.arn
}

output "service_name" {
  value = module.ecs_service.name
}

output "load_balancer_dns_name" {
  value = module.alb.dns_name
}
