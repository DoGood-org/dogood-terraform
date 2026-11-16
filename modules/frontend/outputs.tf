output "app_id" {
  value = aws_amplify_app.this.id
}

output "default_domain" {
  value = aws_amplify_app.this.default_domain
}

output "branch_urls" {
  value = {
    for branch, cfg in var.branches :
    branch => "https://${cfg.subdomain == "" ? "" : "${cfg.subdomain}."}${var.domain_name}"
  }
}

output "certificate_verification_dns_record" {
  description = "CNAME to create in Cloudflare for the Amplify-managed certificate"
  value       = aws_amplify_domain_association.this.certificate_verification_dns_record
}

output "subdomain_dns_records" {
  description = "CNAMEs to create in Cloudflare, per subdomain"
  value       = { for sd in aws_amplify_domain_association.this.sub_domain : sd.prefix => sd.dns_record }
}
