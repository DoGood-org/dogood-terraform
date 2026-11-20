variable "instance_name" {
  description = "EC2 instance name"
  type = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type = string
}

variable "ami_id" {
  description = "EC2 instance AMI"
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_ids" {
  type = list(string)
}

variable "secret_arn" {
  description = "Secret manager ARN"
  type = string
}

variable "rds_resource_id" {
  description = "RDS main resource id"
  type = string
}

variable "rds_secret_arn" {
  description = "Secret ARN, created by RDS"
  type = string
}