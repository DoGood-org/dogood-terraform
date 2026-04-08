resource "aws_db_instance" "main" {
    identifier              = "${var.stage}-db-instance"
    allocated_storage       = 20
    engine                  = "postgres"
    engine_version          = var.db_engine_version
    instance_class          = var.db_instance_class
    db_name                 = var.app_secrets["POSTGRES_DB"]
    username                = var.app_secrets["POSTGRES_USER"]
    password                = var.app_secrets["POSTGRES_PASSWORD"]
    db_subnet_group_name    = var.db_subnet_group_name
    vpc_security_group_ids  = [var.db_security_group_id]
    multi_az                = false
    publicly_accessible     = false 
    skip_final_snapshot     = true
    
    tags = {
        Name = "${var.stage}-db-instance"
    }
}

resource "aws_secretsmanager_secret" "rds_proxy_auth" {
  name                    = "/dogood/${var.stage}/rds-proxy-auth"
  description             = "Credentials used by RDS Proxy to connect to PostgreSQL"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.stage}-rds-proxy-auth"
  }
}

resource "aws_secretsmanager_secret_version" "rds_proxy_auth" {
  secret_id = aws_secretsmanager_secret.rds_proxy_auth.id
  secret_string = jsonencode({
    username = var.app_secrets["POSTGRES_USER"]
    password = var.app_secrets["POSTGRES_PASSWORD"]
  })
}

resource "aws_db_proxy" "pgbouncer" {
  name                   = "${var.stage}-pgbouncer-proxy"
  debug_logging          = false
  engine_family          = "POSTGRESQL"
  idle_client_timeout    = 1800
  require_tls            = false
  role_arn               = aws_iam_role.rds_proxy_role.arn
  vpc_subnet_ids         = var.db_subnet_ids
  vpc_security_group_ids = [var.db_security_group_id]

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.rds_proxy_auth.arn
    iam_auth    = "DISABLED"
  }

  tags = {
    Name = "${var.stage}-pgbouncer-proxy"
  }
}


resource "aws_db_proxy_default_target_group" "pgbouncer" {
  db_proxy_name = aws_db_proxy.pgbouncer.name

  connection_pool_config {
    max_connections_percent      = 100
    max_idle_connections_percent = 50
  }
}

resource "aws_db_proxy_target" "pgbouncer" {
  db_instance_identifier = aws_db_instance.main.identifier
  db_proxy_name          = aws_db_proxy.pgbouncer.name
  target_group_name      = aws_db_proxy_default_target_group.pgbouncer.name
}
