variable "project_id" {
  type        = string
  description = "The GCP project ID to deploy resources into"
}

variable "region" {
  type        = string
  description = "GCP region for deployment"
  default     = "us-central1"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
}

variable "cluster_name" {
  type        = string
  description = "The name of the GKE cluster"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block for GKE"
  default     = "10.2.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "Subnet CIDR for GKE nodes"
  default     = "10.2.1.0/24"
}

variable "gke_num_nodes" {
  type        = number
  description = "Number of GKE nodes"
  default     = 2
}

variable "machine_type" {
  type        = string
  description = "Machine type for nodes"
  default     = "e2-standard-2"
}
