# RDS Proxy (optional); clients authenticate with the RDS-managed master secret
resource "aws_iam_role" "proxy" {
  count = var.proxy_enabled ? 1 : 0

  name = "${var.stage}-db-proxy-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "rds.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name    = "${var.stage}-db-proxy-role"
    Service = "database"
  }
}

resource "aws_iam_role_policy" "proxy" {
  count = var.proxy_enabled ? 1 : 0

  name = "${var.stage}-db-proxy-policy"
  role = aws_iam_role.proxy[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_db_instance.main.master_user_secret[0].secret_arn]
    }]
  })
}

resource "aws_db_proxy" "main" {
  count = var.proxy_enabled ? 1 : 0

  name                   = "${var.stage}-db-proxy"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.proxy[0].arn
  vpc_subnet_ids         = var.proxy_subnet_ids
  vpc_security_group_ids = [var.proxy_security_group_id]
  require_tls            = true
  idle_client_timeout    = 1800
  debug_logging          = false

  auth {
    auth_scheme               = "SECRETS"
    iam_auth                  = "DISABLED"
    client_password_auth_type = "POSTGRES_SCRAM_SHA_256"
    secret_arn                = aws_db_instance.main.master_user_secret[0].secret_arn
  }

  depends_on = [aws_iam_role_policy.proxy]

  tags = {
    Name    = "${var.stage}-db-proxy"
    Service = "database"
  }
}

resource "aws_db_proxy_default_target_group" "main" {
  count = var.proxy_enabled ? 1 : 0

  db_proxy_name = aws_db_proxy.main[0].name
}

resource "aws_db_proxy_target" "main" {
  count = var.proxy_enabled ? 1 : 0

  db_proxy_name          = aws_db_proxy.main[0].name
  target_group_name      = aws_db_proxy_default_target_group.main[0].name
  db_instance_identifier = aws_db_instance.main.identifier
}
