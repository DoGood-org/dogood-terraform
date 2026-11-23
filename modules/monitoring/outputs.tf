output "cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "service_name" {
  value = module.service.name
}

output "admin_secret_arn" {
  value = aws_secretsmanager_secret.grafana.arn
}

output "grafana_url" {
  description = "null when Grafana isn't on the ALB (use the SSM tunnel)"
  value       = var.alb_enabled ? "https://${var.hostname}/" : null
}
