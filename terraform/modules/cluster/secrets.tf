# The secrets of this stack are in the vault, not in a tfvars file.
# Create them once with the commands in terraform/README.md.

data "oci_vault_secrets" "terraform" {
  for_each = toset(["terraform-gh-token", "terraform-github-app-pem"])

  compartment_id = var.compartment_id
  vault_id       = var.vault_id
  name           = each.value
}

data "oci_secrets_secretbundle" "terraform" {
  for_each = data.oci_vault_secrets.terraform

  secret_id = one(each.value.secrets).id
}

locals {
  gh_token       = sensitive(base64decode(data.oci_secrets_secretbundle.terraform["terraform-gh-token"].secret_bundle_content[0].content))
  github_app_pem = sensitive(base64decode(data.oci_secrets_secretbundle.terraform["terraform-github-app-pem"].secret_bundle_content[0].content))
}
