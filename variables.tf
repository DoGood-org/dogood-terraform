variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-west-1"
}

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use for authentication (from ~/.aws/config or ~/.aws/credentials). Leave empty to use the default credential chain."
  type        = string
  default     = null
}

variable "stage" {
  description = "The stage of the project (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "db_instance_class" {
  description = "The instance class for the database"
  type        = string
  default     = "db.t3.micro"
}

variable "db_port" {
  description = "The port for the database"
  type        = number
  default     = 5432
}

variable "app_secrets" {
  type      = map(string)
  sensitive = true
}

variable "cloudflare_api_token" {
  description = "The Cloudflare API token used to manage DNS records"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "The Cloudflare zone ID the DNS record will be created in"
  type        = string
}