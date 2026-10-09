output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_master_secret_arn" {
  description = "ARN of the AWS-managed Secrets Manager secret holding the RDS master credentials"
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "db_address" {
  value = aws_db_instance.main.address
}

output "db_port" {
  value = aws_db_instance.main.port
}
