output "service_name" {
  value = module.grafana.name
}

output "admin_secret_arn" {
  value = aws_secretsmanager_secret.grafana.arn
}
