terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # S3 Backend (AWS) - Active by default to allow successful CI/CD execution without requiring GCP credentials in the runner
  backend "s3" {
    bucket         = "template-cluster-k8s-terraform-state-dev"
    key            = "dev/eks-cluster/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "template-cluster-k8s-tflocks-dev"
    encrypt        = true
  }

  # GCS Backend (Google Cloud Storage) - Uncomment to use GCS as the remote backend for GCP
  # backend "gcs" {
  #   bucket = "template-cluster-k8s-terraform-state-dev"
  #   prefix = "dev/gke-cluster"
  # }
}

provider "aws" {
  region = var.aws_region
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}
