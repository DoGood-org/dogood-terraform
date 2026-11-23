output "vpc_id" {
  value = module.network.vpc_id
}

output "public_subnet_ids" {
  value = module.network.public_subnet_ids
}


output "db_endpoint" {
  value = module.database.db_endpoint
}

output "db_proxy_endpoint" {
  value = module.database.db_proxy_endpoint
}

output "ecs_cluster_arn" {
  value = module.backend.cluster_arn
}

output "ecs_service_name" {
  value = module.backend.service_name
}

output "load_balancer_dns_name" {
  value = module.backend.load_balancer_dns_name
}

output "internal_load_balancer_dns_name" {
  value = module.backend.internal_load_balancer_dns_name
}

output "acm_validation_records" {
  description = "Add in Cloudflare as DNS only (grey cloud); the first apply waits until the certificate is issued"
  value       = module.backend.acm_validation_records
}

output "dns_records" {
  description = "CNAMEs to create in Cloudflare for the public ALB"
  value = merge(
    var.api_hostname == null ? {} : {
      (var.api_hostname) = { type = "CNAME", value = module.backend.load_balancer_dns_name, proxy = "proxied or DNS only (SSL mode Full (strict) when proxied)" }
    },
    var.monitoring_hostname == null ? {} : {
      (var.monitoring_hostname) = { type = "CNAME", value = module.backend.load_balancer_dns_name, proxy = "DNS only: the ALB rule checks the client IP" }
    }
  )
}

output "monitoring_cluster_name" {
  value = one(module.monitoring[*].cluster_name)
}

output "monitoring_service_name" {
  value = one(module.monitoring[*].service_name)
}

output "grafana_url" {
  value = one(module.monitoring[*].grafana_url)
}

output "grafana_admin_secret_arn" {
  value = one(module.monitoring[*].admin_secret_arn)
}
