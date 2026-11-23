output "cluster_arn" {
  value = module.ecs_cluster.arn
}

output "service_name" {
  value = module.ecs_service.name
}

output "load_balancer_dns_name" {
  description = "Public ALB; null when disabled"
  value       = try(module.alb["public"].dns_name, null)
}

output "internal_load_balancer_dns_name" {
  description = "Internal ALB; null when disabled"
  value       = try(module.alb["internal"].dns_name, null)
}

output "https_listener_arn" {
  description = "HTTPS listener of the public ALB; null without TLS"
  value       = local.https_enabled ? module.alb["public"].listeners["https"].arn : null
}

output "acm_validation_records" {
  description = "CNAMEs to add in Cloudflare (DNS only) to validate the ALB certificate"
  value = {
    for o in flatten(aws_acm_certificate.this[*].domain_validation_options) : o.domain_name => {
      name  = o.resource_record_name
      type  = o.resource_record_type
      value = o.resource_record_value
    }
  }
}
