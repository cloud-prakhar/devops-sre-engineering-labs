# Terraform bootstraps exactly two things and then gets out of the way:
#   1. Argo CD itself (Helm chart)
#   2. one root Application that points Argo CD at gitops/root in your fork
# Everything after that — the AppProject, the ApplicationSet, both environments — comes from Git.

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true
  wait             = true
  timeout          = 600

  # Small footprint for 2-3 small nodes: no Dex (no SSO in the lab), no notifications controller,
  # single replicas, modest requests. The UI is reached with kubectl port-forward only.
  values = [yamlencode({
    global = { domain = "argocd.local" }
    configs = {
      params = { "server.insecure" = true } # TLS terminated by kubectl port-forward's tunnel
      cm = {
        "timeout.reconciliation"             = "60s" # poll Git every minute (no webhook in the lab)
        "admin.enabled"                      = true
        "statusbadge.enabled"                = false
        "application.resourceTrackingMethod" = "annotation"
      }
    }
    dex           = { enabled = false }
    notifications = { enabled = false }
    controller = {
      resources = { requests = { cpu = "100m", memory = "256Mi" }, limits = { memory = "768Mi" } }
    }
    repoServer = {
      resources = { requests = { cpu = "50m", memory = "128Mi" }, limits = { memory = "512Mi" } }
    }
    server = {
      resources = { requests = { cpu = "50m", memory = "64Mi" }, limits = { memory = "256Mi" } }
    }
    applicationSet = {
      resources = { requests = { cpu = "20m", memory = "64Mi" }, limits = { memory = "256Mi" } }
    }
    redis = {
      resources = { requests = { cpu = "20m", memory = "32Mi" }, limits = { memory = "128Mi" } }
    }
  })]
}

resource "helm_release" "root_app" {
  name       = "argocd-root"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = "argocd"
  depends_on = [helm_release.argocd] # the Application CRD must exist first

  values = [yamlencode({
    applications = {
      "gitops-root" = {
        namespace  = "argocd"
        project    = "default"
        finalizers = ["resources-finalizer.argocd.argoproj.io"] # deleting it removes what it created
        source = {
          repoURL        = var.repo_url
          targetRevision = var.target_revision
          path           = "projects/aws/09-helm-argocd-gitops/gitops/root"
          helm = {
            valuesObject = {
              repoURL        = var.repo_url
              targetRevision = var.target_revision
            }
          }
        }
        destination = { server = "https://kubernetes.default.svc", namespace = "argocd" }
        syncPolicy = {
          automated = { prune = true, selfHeal = true }
        }
      }
    }
  })]
}
