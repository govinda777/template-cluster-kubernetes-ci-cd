variable "resource_group_name" {
  type        = string
  description = "The name of the resource group"
  default     = "template-k8s-rg"
}

variable "location" {
  type        = string
  description = "Azure region for deployment"
  default     = "eastus2"
}

variable "environment" {
  type        = string
  description = "Deployment environment name"
}

variable "cluster_name" {
  type        = string
  description = "The name of the AKS cluster"
}

variable "vnet_cidr" {
  type        = string
  description = "VNET CIDR block for AKS"
  default     = "10.3.0.0/16"
}

variable "subnet_cidr" {
  type        = string
  description = "Subnet CIDR for AKS nodes"
  default     = "10.3.1.0/24"
}

variable "node_count" {
  type        = number
  description = "Number of nodes in the AKS default pool"
  default     = 2
}

variable "vm_size" {
  type        = string
  description = "VM Size for AKS nodes"
  default     = "Standard_D2s_v5"
}
