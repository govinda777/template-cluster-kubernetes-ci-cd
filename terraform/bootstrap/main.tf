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
}

provider "aws" {
  region = var.aws_region
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# ===============================================================================
# AWS OIDC FOR GITHUB ACTIONS
# ===============================================================================

# Dynamic TLS certificate data source to automatically fetch current GitHub thumbprints
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# 1. OIDC Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]
}

# Trust policy document for GitHub OIDC federated authentication
data "aws_iam_policy_document" "github_actions_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${var.github_org_repo}:*",
        "repo:${split("/", var.github_org_repo)[0]}*:*",
        "repo:${var.github_org_repo}@*:*",
        "repo:${split("/", var.github_org_repo)[0]}*@*:*"
      ]
    }
  }
}

# 2. Roles for Dev, Prod, and Test
resource "aws_iam_role" "github_actions_dev" {
  name               = "github-actions-eks-dev-role"
  description        = "Role assumed by GitHub Actions for Dev environment"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role_policy.json
}

resource "aws_iam_role" "github_actions_prod" {
  name               = "github-actions-eks-prod-role"
  description        = "Role assumed by GitHub Actions for Prod environment"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role_policy.json
}

resource "aws_iam_role" "github_actions_test" {
  name               = "github-actions-eks-test-role"
  description        = "Role assumed by GitHub Actions for Test environment"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role_policy.json
}

# 3. Attach AdministratorAccess to allow full Infrastructure-as-Code (IaC) provisioning
resource "aws_iam_role_policy_attachment" "dev_admin" {
  role       = aws_iam_role.github_actions_dev.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "prod_admin" {
  role       = aws_iam_role.github_actions_prod.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role_policy_attachment" "test_admin" {
  role       = aws_iam_role.github_actions_test.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ===============================================================================
# GCP WORKLOAD IDENTITY FEDERATION FOR GITHUB ACTIONS
# ===============================================================================

# 1. Workload Identity Pool for GitHub Actions
resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Workload Identity Pool for GitHub Actions"
}

# 2. Workload Identity Provider for GitHub Actions
resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-actions-provider"
  display_name                       = "GitHub Actions Provider"
  description                        = "OIDC provider for GitHub Actions"

  attribute_mapping = {
    "google.subject"             = "assertion.sub"
    "attribute.actor"            = "assertion.actor"
    "attribute.repository"       = "assertion.repository"
    "attribute.repository_owner" = "assertion.repository_owner"
  }

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# 3. IAM Service Accounts for Dev, Prod, and Test
resource "google_service_account" "github_actions_dev" {
  account_id   = "github-actions-dev-sa"
  display_name = "GitHub Actions Dev Service Account"
}

resource "google_service_account" "github_actions_prod" {
  account_id   = "github-actions-prod-sa"
  display_name = "GitHub Actions Prod Service Account"
}

resource "google_service_account" "github_actions_test" {
  account_id   = "github-actions-test-sa"
  display_name = "GitHub Actions Test Service Account"
}

# 4. Attach Roles/Owner to Service Accounts to allow full IaC provisioning
resource "google_project_iam_member" "dev_owner" {
  project = var.gcp_project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.github_actions_dev.email}"
}

resource "google_project_iam_member" "prod_owner" {
  project = var.gcp_project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.github_actions_prod.email}"
}

resource "google_project_iam_member" "test_owner" {
  project = var.gcp_project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.github_actions_test.email}"
}

# 5. Workload Identity IAM bindings to allow WIF impersonation on Service Accounts
# Restricted strictly to the specified GitHub repository to match AWS trust policy structure
resource "google_service_account_iam_binding" "dev_impersonation" {
  service_account_id = google_service_account.github_actions_dev.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org_repo}"
  ]
}

resource "google_service_account_iam_binding" "prod_impersonation" {
  service_account_id = google_service_account.github_actions_prod.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org_repo}"
  ]
}

resource "google_service_account_iam_binding" "test_impersonation" {
  service_account_id = google_service_account.github_actions_test.name
  role               = "roles/iam.workloadIdentityUser"

  members = [
    "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_org_repo}"
  ]
}
