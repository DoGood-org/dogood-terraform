variable "stage" {
  type = string
}

variable "app_secrets" {
  type      = map(string)
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

variable "db_engine_version" {
  type    = string
  default = "17.6"
}

variable "deletion_protection" {
  description = "Prevents the RDS instance from being deleted while enabled"
  type        = bool
}

variable "multi_az" {
  description = "Deploy the primary RDS instance with a standby in a second AZ"
  type        = bool
}

variable "availability_zone" {
  description = "AZ for the RDS instance and read replicas when multi_az is false"
  type        = string
  default     = null
}

variable "read_replica_count" {
  description = "Number of RDS read replicas"
  type        = number
  default     = 0
}
