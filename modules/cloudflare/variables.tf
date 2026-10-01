variable "zone_id" {
  description = "The Cloudflare zone ID the DNS record will be created in"
  type        = string
}

variable "subdomain" {
  description = "The subdomain to create the CNAME record for (e.g. the stage/environment name)"
  type        = string
}

variable "target" {
  description = "The target hostname the CNAME record should point to (e.g. the load balancer DNS name)"
  type        = string
}

variable "proxied" {
  description = "Whether the record should be proxied through Cloudflare"
  type        = bool
  default     = true
}
