# --- General ---

variable "stage" {
  description = "The stage of the project (e.g., dev, prod). Must match the selected Terraform workspace."
  type        = string
}

variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-west-1"
}

variable "aws_profile" {
  description = "Named AWS CLI profile to use for authentication (from ~/.aws/config or ~/.aws/credentials). Leave empty to use the default credential chain."
  type        = string
  default     = null
}

# --- Networking ---

variable "vpc_cidr_block" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_endpoints_single_az" {
  description = "Place interface VPC endpoints only in the first AZ (same AZ as single-AZ ECS tasks)"
  type        = bool
  default     = false
}

# --- Database (RDS) ---

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

variable "db_multi_az" {
  description = "Deploy RDS with a standby in a second AZ. When false, RDS is placed in the first AZ."
  type        = bool
  default     = true
}

variable "db_read_replica_count" {
  description = "Number of RDS read replicas"
  type        = number
  default     = 0
}

variable "db_deletion_protection" {
  description = "Enables RDS deletion protection. Set per workspace in its tfvars (e.g. false for dev, true for prod)."
  type        = bool
  default     = true
}

# --- Compute (ECS Fargate) ---

variable "ecs_single_az" {
  description = "Run ECS tasks only in the first AZ"
  type        = bool
  default     = false
}

variable "ecs_task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 512
}

variable "ecs_min_capacity" {
  description = "Minimum number of running ECS tasks"
  type        = number
  default     = 1
}

variable "ecs_max_capacity" {
  description = "Maximum number of running ECS tasks"
  type        = number
  default     = 1
}

variable "app_port" {
  description = "Port the backend listens on (injected as PORT)"
  type        = number
  default     = 5000
}

variable "app_health_check_path" {
  description = "ALB health check path"
  type        = string
  default     = "/health/liveness"
}

variable "ecr_repository_name" {
  description = "ECR repository with the backend image for this stage (must end with -<stage>, e.g. dogood/dogood-backend-dev; only the :latest tag is used, for the initial task definition)"
  type        = string
}

# --- Application ---

variable "app_secrets" {
  type      = map(string)
  sensitive = true
}

# variable "cloudflare_api_token" {
#   description = "The Cloudflare API token used to manage DNS records"
#   type        = string
#   sensitive   = true
# }
#
# variable "cloudflare_zone_id" {
#   description = "The Cloudflare zone ID the DNS record will be created in"
#   type        = string
# }