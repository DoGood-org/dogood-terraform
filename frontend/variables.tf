variable "aws_region" {
  type    = string
  default = "us-west-1"
}

variable "aws_profile" {
  description = "AWS CLI profile; null uses the default chain"
  type        = string
  default     = null
}

variable "name" {
  type    = string
  default = "dogood-frontend"
}

variable "repository" {
  type    = string
  default = "https://github.com/DoGood-org/dogood-frontend"
}

variable "access_token" {
  description = "GitHub PAT with access to the repository; pass via TF_VAR_access_token, needed only to create the app"
  type        = string
  sensitive   = true
  default     = null
}

variable "service_role_arn" {
  description = "Amplify service role (SSR logging)"
  type        = string
}

variable "domain_name" {
  type    = string
  default = "dogood.ink"
}

variable "branches" {
  description = "Git branch => subdomain prefix"
  type = map(object({
    subdomain         = string
    stage             = optional(string)
    enable_auto_build = optional(bool, true)
  }))
}

variable "api_url" {
  description = "Backend URL baked into the build as NEXT_PUBLIC_API_URL; null leaves it unset"
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "App-level build/runtime variables, shared by all branches"
  type        = map(string)
  sensitive   = true
  default     = {}
}
