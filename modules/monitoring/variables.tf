variable "stage" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_id" {
  description = "Public subnet for the Grafana task"
  type        = string
}

variable "cluster_arn" {
  type = string
}

variable "efs_enabled" {
  description = "Keep /var/lib/grafana on EFS"
  type        = bool
}
