variable "cluster_name" {
  type        = string
  description = "The name of the EKS cluster"
}

variable "environment" {
  type        = string
  description = "The environment (e.g. dev, prod)"
}

variable "service_account_name" {
  type        = string
  description = "The Kubernetes ServiceAccount name"
  default     = "api-example-sa"
}

variable "namespace" {
  type        = string
  description = "The Kubernetes namespace where the ServiceAccount lives"
  default     = "dev"
}

variable "role_name" {
  type        = string
  description = "Custom name for the IAM Role"
  default     = ""
}
