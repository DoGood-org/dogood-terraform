variable "stage" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "db_port" {
  type = number
}

variable "app_port" {
  type = number
}

variable "nat_instance_type" {
  type = string
}

variable "app_egress_ports" {
  description = "TCP ports the tasks may reach on the internet through the NAT instance"
  type        = list(number)
}

variable "db_proxy_enabled" {
  type = bool
}
