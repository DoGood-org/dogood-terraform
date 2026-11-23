variable "stage" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "instance_sg_id" {
  type = string
}

variable "alb_sg_id" {
  type = string
}

variable "app_secrets" {
  type      = map(string)
  sensitive = true
}

variable "secret_recovery_window_days" {
  type = number
}

variable "container_image" {
  description = "Initial image; later revisions come from CI"
  type        = string
}

variable "ecr_repository_arn" {
  type = string
}

variable "container_port" {
  type = number
}

variable "db_address" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_master_secret_arn" {
  type = string
}

variable "single_az" {
  type = bool
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "min_capacity" {
  type = number
}

variable "max_capacity" {
  type = number
}

variable "autoscaling_target_cpu_utilization" {
  description = "Target average CPU (%) for the ECS service"
  type        = number
}

variable "health_check_path" {
  type = string
}

variable "public_alb_enabled" {
  description = "Internet-facing ALB in the public subnets"
  type        = bool
}

variable "internal_alb_enabled" {
  description = "Internal ALB in the private subnets (reachable from the VPC only)"
  type        = bool
}

variable "tls_hostnames" {
  description = "Hostnames on the public ALB certificate (first is the primary name); empty: no TLS"
  type        = list(string)
}

variable "api_hostname" {
  description = "Host routed to the app on the HTTPS listener; other hosts get 404. null: no host routing"
  type        = string
}

variable "ecs_exporter_enabled" {
  description = "ecs_exporter sidecar in the backend task (task CPU/memory metrics for Prometheus)"
  type        = bool
}

variable "ecs_exporter_port" {
  type = number
}
