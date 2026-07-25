variable "vpc_cidr" {
  type        = string
  description = "The CIDR block for the VPC"
}

variable "environment" {
  type        = string
  description = "The environment name (e.g. dev, prod)"
}

variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster for tagging subnets"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "List of public subnet CIDR blocks"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "List of private subnet CIDR blocks"
}
