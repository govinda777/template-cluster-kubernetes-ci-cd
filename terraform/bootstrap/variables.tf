variable "aws_region" {
  type        = string
  description = "AWS region for bootstrap"
  default     = "us-east-1"
}

variable "github_org_repo" {
  type        = string
  description = "GitHub Owner/Repository (e.g. govinda777/template-cluster-kubernetes-ci-cd)"
}
