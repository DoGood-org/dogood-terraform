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

output "db_subnet_group_name" {
  value = aws_db_subnet_group.db_subnet_group.name
}
