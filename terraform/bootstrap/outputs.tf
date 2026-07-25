output "aws_region" {
  value       = var.aws_region
  description = "The AWS region"
}

output "github_role_to_assume_dev" {
  value       = aws_iam_role.github_actions_dev.arn
  description = "ARN of the Dev role"
}

output "github_role_to_assume_prod" {
  value       = aws_iam_role.github_actions_prod.arn
  description = "ARN of the Prod role"
}

output "github_role_to_assume_test" {
  value       = aws_iam_role.github_actions_test.arn
  description = "ARN of the Test role"
}

# ===============================================================================
# GCP WORKLOAD IDENTITY FEDERATION OUTPUTS
# ===============================================================================

output "gcp_workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "The full identifier path of the GCP Workload Identity Provider"
}

output "gcp_service_account_dev" {
  value       = google_service_account.github_actions_dev.email
  description = "GCP Service Account Email for Dev"
}

output "gcp_service_account_prod" {
  value       = google_service_account.github_actions_prod.email
  description = "GCP Service Account Email for Prod"
}

output "gcp_service_account_test" {
  value       = google_service_account.github_actions_test.email
  description = "GCP Service Account Email for Test"
}
