# GitHub Actions authenticates with short-lived OIDC tokens; no AWS access keys exist anywhere.
#
# Trust is pinned to ONE repository and ONE GitHub Environment. GitHub puts the environment in the
# token's "sub" claim (repo:OWNER/REPO:environment:NAME), so a workflow on another branch, a fork, or a
# job outside the environment cannot assume these roles — and the environment's required reviewers
# become the approval gate for every release and deploy.

locals {
  oidc_url   = "token.actions.githubusercontent.com"
  github_sub = "repo:${var.github_repository}:environment:${var.github_environment}"
  oidc_arn = (var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn :
  data.aws_iam_openid_connect_provider.github[0].arn)
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.create_github_oidc_provider ? 1 : 0
  url            = "https://${local.oidc_url}"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 0 : 1
  url   = "https://${local.oidc_url}"
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_url}:sub"
      values   = [local.github_sub]
    }
  }
}

# ---------------------------------------------------------------- release: push to one repository

resource "aws_iam_role" "push" {
  name                 = "lab06-gha-push"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "push" {
  statement {
    sid       = "EcrLogin"
    actions   = ["ecr:GetAuthorizationToken"] # account-level API, cannot be scoped to a repository
    resources = ["*"]
  }
  statement {
    sid = "PushToOneRepository"
    actions = [
      "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings", "ecr:GetDownloadUrlForLayer",
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_role_policy" "push" {
  name   = "push-taskboard-image"
  role   = aws_iam_role.push.id
  policy = data.aws_iam_policy_document.push.json
}

# ---------------------------------------------------------------- deploy: run one SSM document on one host

resource "aws_iam_role" "deploy" {
  name                 = "lab06-gha-deploy"
  assume_role_policy   = data.aws_iam_policy_document.github_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid     = "RunShellOnTheDeployHostOnly"
    actions = ["ssm:SendCommand"]
    resources = [
      "arn:aws:ssm:${var.aws_region}::document/AWS-RunShellScript",
      "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/${module.host.instance_id}",
    ]
  }
  statement {
    sid       = "ReadCommandResults"
    actions   = ["ssm:GetCommandInvocation", "ssm:ListCommandInvocations"]
    resources = ["*"] # these APIs do not support resource-level permissions
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "deploy-via-ssm"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

data "aws_caller_identity" "current" {}
