output "bucket" {
  description = "State bucket name."
  value       = aws_s3_bucket.state.id
}

output "region" {
  description = "State bucket region."
  value       = var.aws_region
}

output "backend_config" {
  description = "Contents for a backend.hcl file (shared/scripts/tf-init-backend.sh writes it for you)."
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.state.id}"
    region       = "${var.aws_region}"
    encrypt      = true
    use_lockfile = true
  EOT
}

output "state_access_policy_json" {
  description = "Least-privilege IAM policy for reading and writing state under aws-* keys."
  value       = data.aws_iam_policy_document.state_access.json
}
