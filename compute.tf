resource "aws_instance" "app_server" {
    ami           = data.aws_ami.amazon_linux.id
    instance_type = var.instance_type
    subnet_id     = aws_subnet.public_subnet.id
    vpc_security_group_ids = [ aws_security_group.instance_sg.id ]
    availability_zone = "${var.aws_region}a"
    key_name      = aws_key_pair.ssh_key.key_name
    associate_public_ip_address = true

    tags = {
        Name = "${var.stage}-app-server"
    }
}

resource "aws_key_pair" "ssh_key" {
    key_name   = "dev_deploy_key"
    public_key = file("${var.ssh_key_path}")
}


resource "aws_db_instance" "app_db" {
    db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
    allocated_storage    = 20
    engine               = "postgres"
    engine_version       = "17.6"
    instance_class       = var.db_instance_class
    db_name              = "${var.stage}_db"
    username             = var.postgres_user
    password             = var.postgres_password
    port                 = var.db_port
    multi_az              = true
    publicly_accessible   = false
    vpc_security_group_ids = [ aws_security_group.instance_sg.id ]  

    // Skip final snapshot for testing purposes, but be cautious in production environments
    skip_final_snapshot       = true 

}




