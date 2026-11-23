# Passwords are ephemeral and written write-only, so they are never stored in state.

# --- Grafana admin ---

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

# --- DB role for postgres_exporter (pg_monitor) ---
# The init container sets this password on every task start, so bumping
# secret_string_wo_version rotates it on the next deployment.

ephemeral "aws_secretsmanager_random_password" "db_monitoring" {
  password_length     = 32
  exclude_punctuation = true
}

resource "aws_secretsmanager_secret" "db_monitoring" {
  name                    = "/dogood/${var.stage}/monitoring-db"
  description             = "PostgreSQL role for postgres_exporter (pg_monitor)"
  recovery_window_in_days = 0

  tags = {
    Name    = "/dogood/${var.stage}/monitoring-db"
    Service = "monitoring"
  }
}

resource "aws_secretsmanager_secret_version" "db_monitoring" {
  secret_id = aws_secretsmanager_secret.db_monitoring.id
  secret_string_wo = jsonencode({
    username = local.db_monitoring_user
    password = ephemeral.aws_secretsmanager_random_password.db_monitoring.random_password
  })
  secret_string_wo_version = 1
}
