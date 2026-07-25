# Backend Resources for Terraform State
# This module creates S3 buckets and DynamoDB tables for Terraform state management

provider "aws" {
  region = var.aws_region
}

# S3 Bucket for Dev Environment
resource "aws_s3_bucket" "dev_state" {
  bucket = "template-cluster-k8s-terraform-state-dev"
}

resource "aws_s3_bucket_versioning" "dev_state" {
  bucket = aws_s3_bucket.dev_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dev_state" {
  bucket = aws_s3_bucket.dev_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "dev_state" {
  bucket = aws_s3_bucket.dev_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for Dev Environment Locking
resource "aws_dynamodb_table" "dev_locks" {
  name         = "template-cluster-k8s-tflocks-dev"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}

# S3 Bucket for Prod Environment
resource "aws_s3_bucket" "prod_state" {
  bucket = "template-cluster-k8s-terraform-state-prod"
}

resource "aws_s3_bucket_versioning" "prod_state" {
  bucket = aws_s3_bucket.prod_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "prod_state" {
  bucket = aws_s3_bucket.prod_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "prod_state" {
  bucket = aws_s3_bucket.prod_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table for Prod Environment Locking
resource "aws_dynamodb_table" "prod_locks" {
  name         = "template-cluster-k8s-tflocks-prod"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }
}
