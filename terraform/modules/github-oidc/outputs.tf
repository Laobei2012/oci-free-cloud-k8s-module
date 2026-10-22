output "domain_url" {
  value = local.idcs_endpoint
}

output "client_id" {
  value = oci_identity_domains_app.github.name
}

output "client_secret" {
  value     = oci_identity_domains_app.github.client_secret
  sensitive = true
}

output "plan_user_id" {
  value = oci_identity_domains_user.github["plan"].ocid
}

output "apply_user_id" {
  value = oci_identity_domains_user.github["apply"].ocid
}

# the sub claims of the GitHub tokens, OKE uses them as the Kubernetes user names
output "plan_subject" {
  value = local.subjects.plan
}

output "apply_subject" {
  value = local.subjects.apply
}
