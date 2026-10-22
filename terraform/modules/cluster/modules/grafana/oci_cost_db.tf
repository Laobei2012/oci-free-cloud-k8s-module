# The password of the read-only grafana role in the oci-cost database. The
# ExternalSecrets in gitops/monitoring/oci-cost and gitops/monitoring/grafana read it.
resource "random_password" "oci_cost_db_grafana" {
  length  = 32
  special = false
}

data "oci_kms_vaults" "vault" {
  compartment_id = var.compartment_id

  filter {
    name   = "id"
    values = [var.vault_id]
  }
}

data "oci_kms_keys" "vault_key" {
  compartment_id      = var.compartment_id
  management_endpoint = data.oci_kms_vaults.vault.vaults[0].management_endpoint
}

resource "oci_vault_secret" "oci_cost_db_grafana" {
  compartment_id = var.compartment_id
  key_id         = coalesce(var.vault_key_id, data.oci_kms_keys.vault_key.keys[0].id)
  secret_name    = "oci-cost-db-grafana"
  vault_id       = var.vault_id

  secret_content {
    name         = "password"
    content_type = "BASE64"
    content      = base64encode(random_password.oci_cost_db_grafana.result)
  }
}
