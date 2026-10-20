# The password is ephemeral and written write-only, so it never lands in state.
# Bump secret_string_wo_version to rotate it; Grafana picks it up on the next
# task start (its SQLite database is ephemeral and re-initialised every start).
ephemeral "aws_secretsmanager_random_password" "grafana_admin" {
  password_length     = 32
  exclude_punctuation = true
}

resource "aws_secretsmanager_secret" "grafana" {
  name                    = "/dogood/${var.stage}/grafana"
  description             = "Grafana admin credentials"
  recovery_window_in_days = 0

  tags = {
    Name    = "/dogood/${var.stage}/grafana"
    Service = "monitoring"
  }
}

resource "aws_secretsmanager_secret_version" "grafana" {
  secret_id = aws_secretsmanager_secret.grafana.id
  secret_string_wo = jsonencode({
    admin_user     = "admin"
    admin_password = ephemeral.aws_secretsmanager_random_password.grafana_admin.random_password
  })
  secret_string_wo_version = 1
}
