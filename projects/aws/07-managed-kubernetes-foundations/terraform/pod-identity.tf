# EKS Pod Identity demo: only pods running as ServiceAccount taskboard/pod-identity-demo receive these
# AWS credentials (from the eks-pod-identity-agent on their node), and they can read one parameter.
resource "aws_ssm_parameter" "demo" {
  name  = "/${var.cluster_name}/demo/message"
  type  = "String"
  value = "hello from SSM, read with EKS Pod Identity"
}

data "aws_iam_policy_document" "pod_identity_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "demo" {
  name               = "${var.cluster_name}-pod-identity-demo"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

data "aws_iam_policy_document" "demo" {
  statement {
    actions   = ["ssm:GetParameter"]
    resources = [aws_ssm_parameter.demo.arn]
  }
}

resource "aws_iam_role_policy" "demo" {
  name   = "read-demo-parameter"
  role   = aws_iam_role.demo.id
  policy = data.aws_iam_policy_document.demo.json
}

resource "aws_eks_pod_identity_association" "demo" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = "taskboard"
  service_account = "pod-identity-demo"
  role_arn        = aws_iam_role.demo.arn
}
