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

variable "subnet_public_cidr_block" {
    description = "The CIDR block for subnet inside VPC"
    type = string
}

# variable "subnet_private_cidr_block" {
#     description = "The CIDR block for subnet inside VPC"
#     type        = string
# }


variable "aws_access_key" {
    description = "The AWS access key"
    type        = string
}

variable "aws_secret_key" {
    description = "The AWS secret key"
    type        = string
}

variable "my_ip" {
    description = "Your IP address for security group rules"
    type        = string
}

variable "stage" {
    description = "The stage of the project (e.g., dev, prod)"
    type        = string
    default     = "dev"
}

variable "ami_id" {
    description = "The AMI ID for the EC2 instance"
    type        = string
}

variable "instance_type" {
    description = "The instance type for the EC2 instance"
    type        = string
    default     = "t2.micro"
}


variable "postgres_user" {
    description = "The username for the Postgres database"
    type        = string
    default     = "admin"
}

variable "postgres_password" {
    description = "The password for the Postgres database"
    type        = string
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

variable "ssh_key_path" {
    description = "The path to the SSH public key"
    type        = string
    default     = "~/.ssh/id_rsa.pub"
}