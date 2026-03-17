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
