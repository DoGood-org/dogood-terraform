provider "aws" {
    region = "us-west-1"
    secret_key = var.aws_secret_key
    access_key = var.aws_access_key
}

variable "aws_secret_key" {
  type = string
}

variable "aws_access_key" {
  type = string
}


resource "aws_vpc" "staging_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "staging_vpc"
    }
}
