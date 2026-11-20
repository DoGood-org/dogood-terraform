output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_master_secret_arn" {
  value = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "db_address" {
  value = aws_db_instance.main.address
}

output "client_address" {
  description = "Address the backend connects to: the proxy endpoint when enabled, otherwise the instance"
  value       = var.proxy_enabled ? aws_db_proxy.main[0].endpoint : aws_db_instance.main.address
  depends_on  = [aws_db_proxy_target.main]
}

output "db_proxy_endpoint" {
  value = one(aws_db_proxy.main[*].endpoint)
}

output "db_port" {
  value = aws_db_instance.main.port
}

output "rds_resource_id" {
  description = "RDS main resource id"
  value       = aws_db_instance.main.resource_id
}

output "rds_secret_arn" {
  description = "Secret ARN, created by RDS"
  value       = local.rds_secret_arn
}