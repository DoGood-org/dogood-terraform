# --- General ---

variable "stage" {
  description = "Stage name; must match the workspace"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-1"
}

variable "aws_profile" {
  description = "AWS CLI profile; null uses the default chain"
  type        = string
  default     = null
}

# --- Networking ---

variable "vpc_cidr_block" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "nat_instance_type" {
  description = "fck-nat instance type (internet egress for private subnets)"
  type        = string
  default     = "t4g.nano"
}

variable "nat_per_az" {
  description = "One fck-nat instance per AZ, each private route table through its own AZ; false: one instance in the first AZ"
  type        = bool
  default     = true
}

variable "app_egress_ports" {
  description = "TCP ports ECS tasks may reach on the internet (443; add 587/465 for SMTP)"
  type        = list(number)
  default     = [443]
}

# --- Database (RDS) ---

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_port" {
  description = "RDS port"
  type        = number
  default     = 5432
}

variable "db_multi_az" {
  description = "RDS Multi-AZ; false pins RDS to the first AZ"
  type        = bool
  default     = true
}

variable "db_read_replica_count" {
  description = "RDS read replicas"
  type        = number
  default     = 0
}

variable "db_deletion_protection" {
  description = "RDS deletion protection"
  type        = bool
  default     = true
}

variable "db_skip_final_snapshot" {
  description = "Skip the RDS final snapshot on delete"
  type        = bool
  default     = false
}

variable "db_apply_immediately" {
  description = "Apply RDS changes (version, class, ...) immediately; may cause downtime"
  type        = bool
  default     = false
}

variable "db_proxy_enabled" {
  description = "RDS Proxy in front of the primary; the app connects through it"
  type        = bool
  default     = false
}

# --- Compute (ECS Fargate) ---

variable "ecs_single_az" {
  description = "ECS tasks in the first AZ only"
  type        = bool
  default     = false
}

variable "ecs_task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 512
}

variable "ecs_min_capacity" {
  description = "Minimum ECS tasks"
  type        = number
  default     = 1
}

variable "ecs_max_capacity" {
  description = "Maximum ECS tasks"
  type        = number
  default     = 1
}

variable "ecs_autoscaling_target_cpu_utilization" {
  description = "Target average CPU (%) for ECS autoscaling"
  type        = number
  default     = 75

  validation {
    condition     = var.ecs_autoscaling_target_cpu_utilization > 0 && var.ecs_autoscaling_target_cpu_utilization <= 100
    error_message = "ecs_autoscaling_target_cpu_utilization must be between 1 and 100."
  }
}

variable "app_port" {
  description = "Backend port (PORT)"
  type        = number
  default     = 3000
}

variable "app_health_check_path" {
  description = "ALB health check path"
  type        = string
  default     = "/health/liveness"
}

variable "alb_public_enabled" {
  description = "Internet-facing ALB in the public subnets"
  type        = bool
  default     = true
}

variable "alb_internal_enabled" {
  description = "Internal ALB in the private subnets (VPC only)"
  type        = bool
  default     = false

  validation {
    condition     = var.alb_public_enabled || var.alb_internal_enabled
    error_message = "Enable at least one ALB (alb_public_enabled or alb_internal_enabled)."
  }
}

variable "api_hostname" {
  description = "Public API host (e.g. api.dogood.ink). Enables HTTPS (ACM) on the public ALB, 80 -> 443 redirect and host routing (other hosts get 404); null: plain HTTP"
  type        = string
  default     = null

  validation {
    condition     = var.api_hostname == null || var.alb_public_enabled
    error_message = "api_hostname needs alb_public_enabled = true."
  }
}

variable "ecr_repository_name" {
  description = "Backend ECR repository, ending with -<stage>"
  type        = string
}

# --- Monitoring ---

variable "monitoring_enabled" {
  description = "Deploy the monitoring stack (Prometheus, Grafana, exporters on ECS EC2), node_exporter on NAT and the ecs_exporter sidecar"
  type        = bool
  default     = false
}

variable "monitoring_instance_type" {
  description = "ECS container instance for the monitoring task"
  type        = string
  default     = "t4g.small"
}

variable "monitoring_volume_size" {
  description = "Root gp3 volume of the monitoring instance (GiB)"
  type        = number
  default     = 30
}

variable "prometheus_retention_time" {
  type    = string
  default = "15d"
}

variable "prometheus_retention_size" {
  description = "Prometheus TSDB size cap; keep well below monitoring_volume_size"
  type        = string
  default     = "15GB"
}

variable "backend_metrics_path" {
  description = "Backend app metrics path scraped on app_port; null: don't scrape the app"
  type        = string
  default     = "/metrics"
}

variable "monitoring_hostname" {
  description = "Grafana host on the public ALB (e.g. monitoring.dogood.ink); null: Grafana only through the SSM tunnel"
  type        = string
  default     = null

  validation {
    condition     = var.monitoring_hostname == null || (var.monitoring_enabled && var.api_hostname != null)
    error_message = "monitoring_hostname needs monitoring_enabled = true and api_hostname (HTTPS listener)."
  }
}

variable "monitoring_allowed_cidrs" {
  description = "Source IPs (CIDR) allowed to reach monitoring_hostname, max 4 (ALB rule limit); others get 403"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.monitoring_allowed_cidrs) <= 4 && alltrue([for c in var.monitoring_allowed_cidrs : can(cidrhost(c, 0))])
    error_message = "monitoring_allowed_cidrs: at most 4 valid CIDRs."
  }

  validation {
    condition     = var.monitoring_hostname == null || length(var.monitoring_allowed_cidrs) > 0
    error_message = "monitoring_hostname needs at least one CIDR in monitoring_allowed_cidrs."
  }
}

# --- Application ---

variable "app_secrets" {
  type      = map(string)
  sensitive = true
}

variable "app_secret_recovery_window_days" {
  description = "Recovery window for /dogood/<stage>/env; 0 deletes immediately"
  type        = number
  default     = 7
}

