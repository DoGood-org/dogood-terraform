resource "aws_secretsmanager_secret" "app_env" {
  name                    = "/dogood/${var.stage}/env"
  description             = "App environment variables"
  recovery_window_in_days = var.secret_recovery_window_days

  tags = {
    Name    = "/dogood/${var.stage}/env"
    Service = "application"
  }
}

resource "aws_secretsmanager_secret_version" "app_env" {
  secret_id     = aws_secretsmanager_secret.app_env.id
  secret_string = jsonencode(var.app_secrets)
}
