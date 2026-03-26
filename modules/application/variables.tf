variable "stage" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "ssh_key_path" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "instance_sg_id" {
  type = string
}

variable "db_endpoint" {
  type = string
}

variable "app_secrets" {
  type      = map(string)
  sensitive = true
}

variable "container_image" {
  type    = string
  default = "104363824351.dkr.ecr.us-west-1.amazonaws.com/dogood-backend:latest"
}

variable "container_port" {
  type    = number
  default = 5000
}

variable "ecs_execution_role_name" {
  type    = string
  default = "ecsExecutionRole"
}

variable "ec2_role_name" {
  type    = string
  default = "EC2AccessToECR"
}


variable "alb_sg_id" {
  type = string
}


variable "private_subnet_ids" {
  type = list(string)
}