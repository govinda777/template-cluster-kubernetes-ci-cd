variable "aws_region" {
  type        = string
  description = "AWS region for deployment"
  default     = "us-east-1"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
  default     = "dev"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the Dev VPC"
  default     = "10.0.0.0/16"
}

variable "cluster_name" {
  type        = string
  description = "EKS Cluster Name"
  default     = "template-eks-cluster-dev"
}

# ===============================================================================
# GCP GKE DEFAULT VARIABLES
# ===============================================================================
variable "gcp_project_id" {
  type        = string
  description = "The GCP project ID to deploy GKE into"
  default     = "template-gcp-project-dev"
}

variable "gcp_region" {
  type        = string
  description = "GCP region for GKE deployment"
  default     = "us-central1"
}

variable "gcp_zone" {
  type        = string
  description = "GCP zone for GKE deployment"
  default     = "us-central1-a"
}

variable "enable_gke" {
  type        = bool
  description = "Toggle to enable/disable GKE cluster deployment"
  default     = false
}
