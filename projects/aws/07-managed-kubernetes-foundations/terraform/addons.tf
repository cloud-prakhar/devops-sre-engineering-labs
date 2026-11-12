# EKS managed add-ons, pinned to the newest version compatible with the cluster's Kubernetes version.
locals {
  addons_before_nodes = ["vpc-cni", "kube-proxy", "eks-pod-identity-agent"]
  addons_after_nodes  = ["coredns", "metrics-server"]
  # Add-on configuration (JSON validated by EKS against each add-on's schema).
  addon_configuration = {
    # The VPC CNI's network policy agent enforces Kubernetes NetworkPolicy (used from AWS 08 on).
    "vpc-cni" = jsonencode({ enableNetworkPolicy = var.enable_network_policy ? "true" : "false" })
  }
}

data "aws_eks_addon_version" "this" {
  for_each           = toset(concat(local.addons_before_nodes, local.addons_after_nodes))
  addon_name         = each.value
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

resource "aws_eks_addon" "before_nodes" {
  for_each                    = toset(local.addons_before_nodes)
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.value
  addon_version               = data.aws_eks_addon_version.this[each.value].version
  configuration_values        = lookup(local.addon_configuration, each.value, null)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "after_nodes" {
  for_each                    = toset(local.addons_after_nodes)
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.value
  addon_version               = data.aws_eks_addon_version.this[each.value].version
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_node_group.default]
}
