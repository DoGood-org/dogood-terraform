output "db_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_master_secret_arn" {
  value = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "db_address" {
  value = aws_db_instance.main.address
}

output "db_port" {
  value = aws_db_instance.main.port
}
