output "cluster_id" {
  value = aws_ecs_cluster.main.id
}

output "service_name" {
  value = aws_ecs_service.app.name
}

output "load_balancer_dns_name" {
  value = aws_lb.app_lb.dns_name
}

output "secrets_manager_secret_arn" {
  value = aws_secretsmanager_secret.app_env.arn
}

output "ssh_key" {
  value = aws_key_pair.ssh_key.key_name
} 
