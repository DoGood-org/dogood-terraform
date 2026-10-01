resource "cloudflare_record" "app" {
  zone_id = var.zone_id
  name    = var.subdomain
  type    = "CNAME"
  content = var.target
  proxied = var.proxied
  ttl     = 1
}
