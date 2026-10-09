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
  description = "Port the application container listens on"
  type        = number
}

variable "vpc_endpoints_single_az" {
  description = "Place interface VPC endpoints only in the first private subnet's AZ"
  type        = bool
}
