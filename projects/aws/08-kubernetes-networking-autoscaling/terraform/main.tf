# AWS-side prerequisites for the AWS Load Balancer Controller on the AWS 07 cluster. The controller
# itself is installed with Helm (scripts/install-controller.sh); Terraform owns only IAM.

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

# Official policy for controller v3.6.2, vendored unchanged from
# https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.6.2/docs/install/iam_policy.json
# Update it together with the chart version in scripts/install-controller.sh.
resource "aws_iam_policy" "lbc" {
  name        = "${var.cluster_name}-aws-load-balancer-controller"
  description = "AWS Load Balancer Controller v3.6.2 (official policy)"
  policy      = jsonencode(jsondecode(file("${path.module}/policies/aws-load-balancer-controller-v3.6.2.json")))
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

resource "aws_iam_role" "lbc" {
  name               = "${var.cluster_name}-aws-load-balancer-controller"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_assume.json
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

# Only the controller's ServiceAccount gets these permissions (see AWS 07 Pod Identity).
resource "aws_eks_pod_identity_association" "lbc" {
  cluster_name    = data.aws_eks_cluster.this.name
  namespace       = "kube-system"
  service_account = "aws-load-balancer-controller"
  role_arn        = aws_iam_role.lbc.arn
}
