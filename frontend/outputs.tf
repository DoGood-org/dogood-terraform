output "app_id" {
  value = module.frontend.app_id
}

output "default_domain" {
  value = module.frontend.default_domain
}

output "branch_urls" {
  value = module.frontend.branch_urls
}

output "certificate_verification_dns_record" {
  value = module.frontend.certificate_verification_dns_record
}

output "subdomain_dns_records" {
  value = module.frontend.subdomain_dns_records
}
