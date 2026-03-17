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
    
    skip_final_snapshot     = true
    
    tags = {
        Name = "${var.stage}-db-instance"
    }
}