variable "stage" {
  type = string
}

# --- Network ---

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  description = "Private subnets for the container instance and the task"
  type        = list(string)
}

variable "security_group_id" {
  description = "Task SG from the networking module (scrape, RDS and ALB rules live there)"
  type        = string
}

# --- Container instance ---

variable "instance_type" {
  description = "ECS container instance type; the task reserves 2 vCPU / 1536 MiB (fits t4g.small)"
  type        = string
}

variable "volume_size" {
  description = "Root gp3 volume (GiB); holds the Docker volumes with Prometheus and Grafana data"
  type        = number
}

variable "prometheus_retention_time" {
  type = string
}

variable "prometheus_retention_size" {
  description = "TSDB size cap, keep well below volume_size"
  type        = string
}

# --- Scrape targets ---

variable "backend_cluster_arn" {
  type = string
}

variable "backend_service_name" {
  type = string
}

variable "app_port" {
  type = number
}

variable "backend_metrics_path" {
  description = "App metrics path scraped on app_port; null: don't scrape the app"
  type        = string
}

variable "ecs_exporter_port" {
  type = number
}

variable "node_exporter_port" {
  type = number
}

variable "grafana_port" {
  type = number
}

variable "probe_url" {
  description = "URL probed by blackbox_exporter (through NAT); null: no probe"
  type        = string
}

variable "db_address" {
  description = "RDS instance address (not the proxy)"
  type        = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

variable "db_master_secret_arn" {
  description = "Used only by the init container that creates the pg_monitor role"
  type        = string
}

# --- Grafana access through the ALB ---

variable "alb_enabled" {
  description = "Expose Grafana through the public ALB HTTPS listener"
  type        = bool
}

variable "https_listener_arn" {
  type = string
}

variable "hostname" {
  description = "Grafana host on the ALB (monitoring.*)"
  type        = string
}

variable "allowed_cidrs" {
  description = "Source IPs allowed to reach Grafana; anything else on the host gets 403"
  type        = list(string)
}
