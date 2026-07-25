variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}

variable "environment" {
  type        = string
  description = "Environment name (dev, prod, test)"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the cluster will be created"
}

variable "subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs for the EKS cluster"
}

variable "kubernetes_version" {
  type        = string
  description = "Kubernetes version for the EKS cluster"
  default     = "1.36"
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of worker nodes"
  default     = 2
}

variable "node_max_size" {
  type        = number
  description = "Maximum number of worker nodes"
  default     = 4
}

variable "node_min_size" {
  type        = number
  description = "Minimum number of worker nodes"
  default     = 1
}

variable "node_instance_types" {
  type        = list(string)
  description = "Instance types for worker nodes"
  default     = ["t3.medium"]
}
