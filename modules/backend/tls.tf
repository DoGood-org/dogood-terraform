# ACM certificate for the public ALB (api.* and monitoring.*), validated by DNS records
# that are added by hand in Cloudflare (see the acm_validation_records output). ACM reuses
# the same validation CNAME for a name in this account, so a recreated stage validates
# again without new DNS changes.
locals {
  https_enabled = var.public_alb_enabled && length(var.tls_hostnames) > 0
  host_routing  = local.https_enabled && var.api_hostname != null
}

resource "aws_acm_certificate" "this" {
  count = local.https_enabled ? 1 : 0

  domain_name               = var.tls_hostnames[0]
  subject_alternative_names = slice(var.tls_hostnames, 1, length(var.tls_hostnames))
  validation_method         = "DNS"

  tags = {
    Name    = "${var.stage}-alb-certificate"
    Service = "backend"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Waits (up to 75 min) until the validation CNAMEs exist and the certificate is issued
resource "aws_acm_certificate_validation" "this" {
  count = local.https_enabled ? 1 : 0

  certificate_arn = aws_acm_certificate.this[0].arn
}
