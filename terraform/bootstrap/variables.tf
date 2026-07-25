variable "aws_region" {
  type        = string
  description = "AWS region for bootstrap"
  default     = "us-east-1"
}

variable "github_org_repo" {
  type        = string
  description = "GitHub Owner/Repository (e.g. govinda777/template-cluster-kubernetes-ci-cd)"
}

variable "gcp_project_id" {
  type        = string
  description = "The GCP project ID to configure WIF and Service Accounts"
  default     = "template-gcp-project-dev"
}

variable "gcp_region" {
  type        = string
  description = "GCP region for bootstrap resources"
  default     = "us-central1"
}
