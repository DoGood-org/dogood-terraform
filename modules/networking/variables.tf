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

variable "vpc_endpoints_single_az" {
  type = bool
}
