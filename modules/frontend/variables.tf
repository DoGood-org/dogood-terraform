variable "name" {
  type = string
}

variable "repository" {
  description = "GitHub repository URL"
  type        = string
}

variable "access_token" {
  description = "GitHub personal access token; needed only when the app is created"
  type        = string
  sensitive   = true
  default     = null
}

variable "service_role_arn" {
  description = "Amplify service role (SSR logging)"
  type        = string
}

variable "environment_variables" {
  description = "App-level build/runtime variables, shared by all branches"
  type        = map(string)
  sensitive   = true
}

variable "domain_name" {
  type = string
}

variable "branches" {
  description = "Git branch => subdomain prefix (\"\" for the apex)"
  type = map(object({
    subdomain         = string
    stage             = optional(string)
    enable_auto_build = optional(bool, true)
  }))
}
