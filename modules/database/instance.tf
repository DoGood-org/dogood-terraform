resource "aws_db_instance" "main" {
  identifier                  = "${var.stage}-db-instance"
  allocated_storage           = 20
  engine                      = "postgres"
  engine_version              = var.db_engine_version
  instance_class              = var.db_instance_class
  port                        = var.db_port
  db_name                     = var.app_secrets["POSTGRES_DB"]
  username                    = var.app_secrets["POSTGRES_USER"]
  manage_master_user_password = true
  db_subnet_group_name        = var.db_subnet_group_name
  vpc_security_group_ids      = [var.db_security_group_id]
  skip_final_snapshot         = true
  deletion_protection         = var.deletion_protection
  storage_encrypted           = true

  multi_az                = var.multi_az
  availability_zone       = var.multi_az ? null : var.availability_zone
  backup_retention_period = 7
  backup_window           = "03:00-04:00"

  tags = {
    Name    = "${var.stage}-db-instance"
    Service = "database"
  }
}

resource "aws_db_instance" "replica" {
  count = var.read_replica_count

  identifier             = "${var.stage}-db-replica-${count.index + 1}"
  replicate_source_db    = aws_db_instance.main.identifier
  instance_class         = var.db_instance_class
  vpc_security_group_ids = [var.db_security_group_id]
  availability_zone      = var.multi_az ? null : var.availability_zone
  skip_final_snapshot    = true
  deletion_protection    = var.deletion_protection
  storage_encrypted      = true

  tags = {
    Name    = "${var.stage}-db-replica-${count.index + 1}"
    Service = "database"
  }
}
