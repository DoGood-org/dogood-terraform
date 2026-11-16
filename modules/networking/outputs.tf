output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "instance_security_group_id" {
  value = module.instance_sg.id
}

output "alb_security_group_id" {
  value = module.alb_sg.id
}

output "db_security_group_id" {
  value = module.db_sg.id
}

output "db_proxy_security_group_id" {
  description = "null when the proxy is disabled"
  value       = module.db_proxy_sg.id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.db_subnet_group.name
}

output "azs" {
  value = local.azs
}

output "nat_public_ip" {
  description = "Egress IP of the private subnets (for third-party allowlists)"
  value       = module.nat.instance_public_ip
}
