resource "aws_instance" "proxy" {
    ami                    = var.ami_id
    instance_type          = var.instance_type
  subnet_id              = var.subnet_id
    security_groups        = var.security_groups
    key_name               = var.ssh_key

    associate_public_ip_address = true
    tags = {
        Name  = "proxy-${var.stage}"
        Stage = var.stage
    }
}

