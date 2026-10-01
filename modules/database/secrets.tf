resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "/dogood/${var.stage}/db-proxy"
  description             = "RDS proxy credentials"
  recovery_window_in_days = 0

  tags = merge(local.default_tags, {
    Name    = "${var.stage}-db-proxy-secret"
    Service = "database"
  })
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = var.app_secrets["POSTGRES_USER"]
    password = var.app_secrets["POSTGRES_PASSWORD"]
  })
}
