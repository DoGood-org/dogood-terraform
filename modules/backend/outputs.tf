output "cluster_arn" {
  value = module.ecs_cluster.arn
}

output "service_name" {
  value = module.ecs_service.name
}

output "load_balancer_dns_name" {
  description = "Public ALB; null when disabled"
  value       = try(module.alb["public"].dns_name, null)
}

output "internal_load_balancer_dns_name" {
  description = "Internal ALB; null when disabled"
  value       = try(module.alb["internal"].dns_name, null)
}
