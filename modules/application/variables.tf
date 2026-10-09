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

variable "container_image" {
  description = "Bootstrap image used only on initial creation of the ECS task definition. ignore_task_definition_changes is enabled so subsequent deployments (new image tags/revisions) are rolled out by the GitHub Actions pipeline via OIDC, not by Terraform."
  type        = string
}

variable "ecr_repository_arn" {
  description = "ARN of the ECR repository the execution role may pull from"
  type        = string
}

variable "container_port" {
  type    = number
  default = 5000
}

variable "db_address" {
  description = "Private hostname of the RDS instance"
  type        = string
}

variable "db_port" {
  description = "Port of the RDS instance"
  type        = number
}

variable "db_master_secret_arn" {
  description = "ARN of the RDS-managed master credentials secret"
  type        = string
}

variable "single_az" {
  description = "Run ECS tasks only in the first private subnet's AZ"
  type        = bool
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 512
}

variable "min_capacity" {
  description = "Minimum number of running ECS tasks"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Maximum number of running ECS tasks"
  type        = number
  default     = 1
}

variable "health_check_path" {
  description = "ALB target group health check path"
  type        = string
  default     = "/health/liveness"
}

variable "health_check_grace_period_seconds" {
  description = "Seconds ECS ignores failing ALB health checks after a task starts"
  type        = number
  default     = 60
}
