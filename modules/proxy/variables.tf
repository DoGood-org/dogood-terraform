variable "ami_id" {
    description = "The AMI ID for the EC2 instance"
    type        = string
}

variable "instance_type" {
    description = "The instance type for the EC2 instance"
    type        = string
    default     = "t2.micro"
}

variable "ssh_key_path" {
    description = "The path to the SSH public key"
    type        = string
}

variable "stage" {
    description = "The stage of the project (e.g., dev, prod)"
    type        = string
    default     = "dev"
}

variable "subnet_id" {
    description = "The subnet ID for the EC2 instance"
    type        = string
}

variable "security_groups" {
    description = "The security group ID for the EC2 instance"
    type        = list(string)
}

variable "ssh_key" {
    description = "The name of the SSH key pair to use for the EC2 instance"
    type        = string
}