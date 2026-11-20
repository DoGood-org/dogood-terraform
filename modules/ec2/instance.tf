resource "aws_instance" "main" {
  ami                           = var.ami_id
  instance_type                 = var.instance_type
  subnet_id                     = var.subnet_id
  vpc_security_group_ids        = var.security_group_ids
  iam_instance_profile          = "ec2-execution-role"
  associate_public_ip_address   = true

   metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  tags = {
    Name = "${var.instance_name}"
    Service = "backend"
  }
}
