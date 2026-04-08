output "db_endpoint" {
	value = aws_db_instance.main.endpoint
}

output "db_identifier" {
	value = aws_db_instance.main.identifier
}

output "db_proxy_endpoint" {
	value = aws_db_proxy.pgbouncer.endpoint
}
