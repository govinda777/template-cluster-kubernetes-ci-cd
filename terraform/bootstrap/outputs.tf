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
