output "argocd_ui" {
  description = "Open the Argo CD UI on https? No: plain http over a port-forward tunnel."
  value       = "kubectl -n argocd port-forward svc/argocd-server 8080:80   # then http://localhost:8080 (user admin)"
}

output "admin_password_command" {
  description = "Initial admin password (rotate it in the exercises, then delete the secret)."
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
}

output "repo_url" {
  description = "Repository Argo CD watches."
  value       = var.repo_url
}
