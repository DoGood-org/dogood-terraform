provider "aws" {
  region = var.aws_region
  secret_key = var.aws_secret_key
  access_key = var.aws_access_key
}

variable "aws_region" {
    type = string
}

variable "aws_access_key" {
    type = string
}

variable "aws_secret_key" {
    type = string
}

variable "vpc_cidr_block" {
    type = string
}

resource "aws_vpc" "backend_vpc" {
    cidr_block = var.vpc_cidr_block
    tags = {
        Name = "backend_vpc"
    }
}