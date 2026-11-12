# Shared Helm charts

| Chart | Used by | Notes |
|---|---|---|
| [taskboard](taskboard/) | AWS 09 (Argo CD, dev + prod); later Kubernetes labs | Same objects as the AWS 07/08 Kustomize manifests; `values.schema.json` accepts only `sha256:` digests and rejects `0.0.0.0/0` for the ALB |

```bash
helm lint shared/helm-charts/taskboard -f shared/helm-charts/taskboard/ci/test-values.yaml
helm template taskboard shared/helm-charts/taskboard -f projects/aws/09-helm-argocd-gitops/environments/prod/values.yaml
scripts/validate.sh helm      # lint + render with CI values and every environment, then kubeconform
```

Rules: keep defaults safe (no Ingress, NetworkPolicy on, PDB on); never template a field another
controller owns (`replicas` is omitted when autoscaling is enabled); bump `version` in `Chart.yaml` on every
template change.
