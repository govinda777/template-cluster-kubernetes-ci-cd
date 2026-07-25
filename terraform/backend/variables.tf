variable "aws_region" {
  type        = string
  description = "AWS region for backend resources"
  default     = "us-east-1"
}

variable "gcp_project_id" {
  type        = string
  description = "The GCP project ID to deploy GCS state buckets into"
  default     = "template-gcp-project-dev"
}

variable "gcp_region" {
  type        = string
  description = "GCP region for GCS backend resources"
  default     = "us-central1"
}
