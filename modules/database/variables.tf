variable "stage" {
  type = string
}

variable "db_name" {
  type      = string
  sensitive = true
}

variable "db_username" {
  type      = string
  sensitive = true
}

variable "db_instance_class" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_subnet_group_name" {
  type = string
}

variable "db_security_group_id" {
  type = string
}

variable "deletion_protection" {
  type = bool
}

variable "skip_final_snapshot" {
  type = bool
}

variable "multi_az" {
  type = bool
}

variable "availability_zone" {
  description = "Used when multi_az is false"
  type        = string
}

variable "read_replica_count" {
  type = number
}

variable "apply_immediately" {
  description = "Apply instance changes now instead of in the maintenance window"
  type        = bool
}

variable "iam_auth_enabled" {
  description = "Enable IAM Authentication"
  type = bool
}

variable "proxy_enabled" {
  description = "Put an RDS Proxy in front of the primary instance"
  type        = bool
}

variable "proxy_subnet_ids" {
  description = "At least two subnets in different AZs"
  type        = list(string)
}

variable "proxy_security_group_id" {
  description = "null when the proxy is disabled"
  type        = string
}
