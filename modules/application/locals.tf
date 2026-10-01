locals {
  default_tags = {
    Environment = var.stage
    Project     = "dogood"
    ManagedBy   = "terraform"
  }
}
