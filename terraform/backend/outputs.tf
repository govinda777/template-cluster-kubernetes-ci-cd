output "dev_state_bucket" {
  description = "Name of the dev state S3 bucket"
  value       = aws_s3_bucket.dev_state.id
}

output "dev_locks_table" {
  description = "Name of the dev locks DynamoDB table"
  value       = aws_dynamodb_table.dev_locks.id
}

output "prod_state_bucket" {
  description = "Name of the prod state S3 bucket"
  value       = aws_s3_bucket.prod_state.id
}

output "prod_locks_table" {
  description = "Name of the prod locks DynamoDB table"
  value       = aws_dynamodb_table.prod_locks.id
}
