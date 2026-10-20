variable "stage" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "Public subnet for the Grafana task. The public IP is used for egress only (CloudWatch API, SSM, Docker Hub); the security group has no ingress."
  type        = string
}

variable "cluster_arn" {
  description = "ECS cluster to run the Grafana service in"
  type        = string
}

variable "grafana_image" {
  description = "Grafana image pinned by digest (multi-arch index, includes arm64)"
  type        = string
  default     = "grafana/grafana:13.2.4@sha256:dbbc38ea21103cefb50396340cd88afec779c7e070b0a7bf5a75b4ce46651d3f"
}

variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory (MiB). Grafana 13 saturates 512 MiB as soon as dashboards are used."
  type        = number
  default     = 1024
}
