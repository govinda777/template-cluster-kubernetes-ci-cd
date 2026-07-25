provider "aws" {
  region = var.aws_region
}

# 1. OIDC Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
    "227203b5317f3818cab5b5ce596132bf36748c0e"
  ]
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
      values   = ["repo:${var.github_org_repo}:*"]
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
