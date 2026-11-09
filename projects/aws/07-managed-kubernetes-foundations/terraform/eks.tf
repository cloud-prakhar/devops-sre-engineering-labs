data "aws_iam_policy_document" "eks_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

#trivy:ignore:AWS-0040 Public endpoint is restricted to allowed_api_cidrs (your /32); private endpoint is also enabled.
#trivy:ignore:AWS-0041 Restricted by allowed_api_cidrs; 0.0.0.0/0 is rejected by variable validation.
#trivy:ignore:AWS-0038 Control-plane logging is billed per GB; opt in with control_plane_log_types.
#trivy:ignore:AWS-0039 EKS envelope-encrypts Kubernetes API data with an AWS-owned key by default; a customer-managed KMS key ($1/month) is optional.
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = module.vpc.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    public_access_cidrs     = var.allowed_api_cidrs
  }

  # Access entries (EKS API) instead of the aws-auth ConfigMap; no implicit admin for the creator.
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }

  # STANDARD: the cluster is upgraded when standard support ends instead of silently moving to
  # extended support, which multiplies the control-plane price.
  upgrade_policy {
    support_type = "STANDARD"
  }

  enabled_cluster_log_types = var.control_plane_log_types

  depends_on = [aws_iam_role_policy_attachment.cluster]
}

# ---------------------------------------------------------------- who may use the cluster

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = local.admin_principal_arn
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope {
    type = "cluster"
  }
}

# A "developer" IAM role mapped to the Kubernetes group lab07-developers. It gets no EKS access
# policy: its permissions come only from the Role/RoleBinding in k8s/base/rbac-developer.yaml.
data "aws_iam_policy_document" "developer_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [local.admin_principal_arn]
    }
  }
}

resource "aws_iam_role" "developer" {
  name               = "${var.cluster_name}-developer"
  assume_role_policy = data.aws_iam_policy_document.developer_assume.json
}

data "aws_iam_policy_document" "developer" {
  statement {
    sid       = "GetKubeconfigOnly"
    actions   = ["eks:DescribeCluster"]
    resources = [aws_eks_cluster.this.arn]
  }
}

resource "aws_iam_role_policy" "developer" {
  name   = "describe-cluster"
  role   = aws_iam_role.developer.id
  policy = data.aws_iam_policy_document.developer.json
}

resource "aws_eks_access_entry" "developer" {
  cluster_name      = aws_eks_cluster.this.name
  principal_arn     = aws_iam_role.developer.arn
  type              = "STANDARD"
  kubernetes_groups = ["lab07-developers"]
}
