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
  default     = "104363824351.dkr.ecr.us-west-1.amazonaws.com/dogood-backend:latest"
}

variable "container_port" {
  type    = number
  default = 5000
}

variable "container_entrypoint" {
  description = "Overrides the container ENTRYPOINT. Leave as null to use the image's default."
  type        = list(string)
  default     = null
}

variable "container_cpu" {
  description = "Container-level CPU units (soft limit / QoS share). Leave as null to omit and let the task-level cpu apply."
  type        = number
  default     = null
}

variable "container_memory_reservation" {
  description = "Soft memory limit (MiB) reserved for the container (QoS). The hard limit is still bounded by the task-level memory."
  type        = number
  default     = null
}

variable "ecs_execution_role_name" {
  type    = string
  default = "ecsExecutionRole"
}
