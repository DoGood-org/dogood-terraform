output "vpc_id" {
	value = aws_vpc.primary_vpc.id
}

output "public_subnet_ids" {
	value = aws_subnet.public_subnet[*].id
}

output "private_subnet_ids" {
	value = aws_subnet.private_subnet[*].id
}

output "instance_security_group_id" {
	value = aws_security_group.instance_sg.id
}

output "db_security_group_id" {
	value = aws_security_group.db_sg.id
}

output "db_subnet_group_name" {
	value = aws_db_subnet_group.db_subnet_group.name
}
