resource "aws_db_proxy" "main" {
  name                   = "${var.stage}-db-proxy"
  engine_family          = "POSTGRESQL"
  role_arn               = aws_iam_role.db_proxy.arn
  vpc_subnet_ids         = var.private_subnet_ids
  vpc_security_group_ids = [var.db_security_group_id]

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_db_instance.main.master_user_secret[0].secret_arn
    iam_auth    = "DISABLED"
  }

  tags = {
    Name    = "${var.stage}-db-proxy"
    Service = "database"
  }
}

resource "aws_db_proxy_default_target_group" "main" {
  db_proxy_name = aws_db_proxy.main.name

  connection_pool_config {
    max_connections_percent      = 100
    max_idle_connections_percent = 50
    connection_borrow_timeout    = 120
  }
}

resource "aws_db_proxy_target" "main" {
  db_proxy_name          = aws_db_proxy.main.name
  target_group_name      = aws_db_proxy_default_target_group.main.name
  db_instance_identifier = aws_db_instance.main.identifier
}
