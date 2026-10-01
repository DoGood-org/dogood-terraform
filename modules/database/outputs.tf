output "db_endpoint" {
  value = aws_db_proxy.main.endpoint
}

output "db_instance_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "db_identifier" {
  value = aws_db_instance.main.identifier
}

output "db_proxy_name" {
  value = aws_db_proxy.main.name
}
