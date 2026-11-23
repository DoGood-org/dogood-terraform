variable "stage" {
  type = string
}

variable "vpc_cidr_block" {
  type = string
}

variable "db_port" {
  type = number
}

variable "app_port" {
  type = number
}

variable "nat_instance_type" {
  type = string
}

variable "app_egress_ports" {
  description = "TCP ports the tasks may reach on the internet through the NAT instance"
  type        = list(number)
}

variable "db_proxy_enabled" {
  type = bool
}

variable "nat_per_az" {
  description = "One NAT instance per AZ (each private route table uses its own AZ); false: one instance in the first AZ"
  type        = bool
}

variable "monitoring_enabled" {
  description = "Create the monitoring task SG and the scrape / Grafana rules"
  type        = bool
}

variable "node_exporter_enabled" {
  description = "Install node_exporter on the NAT instances"
  type        = bool
}

variable "node_exporter_port" {
  type = number
}

variable "ecs_exporter_port" {
  description = "ecs_exporter sidecar port in the backend task"
  type        = number
}

variable "grafana_port" {
  type = number
}
