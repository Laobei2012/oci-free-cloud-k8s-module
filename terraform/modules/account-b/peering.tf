# Remote peering to the k8s VCN of account A (other tenancy, other region).
# Account A is the requestor, account B admits it, see terraform/modules/account-a/peering.tf
locals {
  policy_scope = var.compartment_id == var.tenancy_id ? "tenancy" : "compartment id ${var.compartment_id}"
}

resource "oci_core_drg" "k8s_b_drg" {
  compartment_id = var.compartment_id
  display_name   = "k8s-b-drg"
}

resource "oci_core_drg_attachment" "k8s_b_vcn" {
  drg_id       = oci_core_drg.k8s_b_drg.id
  display_name = "k8s-b-vcn"

  network_details {
    id   = module.vcn.vcn_id
    type = "VCN"
  }
}

# acceptor policy, account A endorses the same group
resource "oci_identity_policy" "account_a_peering" {
  compartment_id = var.tenancy_id
  name           = "admit-account-a-remote-peering"
  description    = "Allows account A to connect its k8s DRG to the k8s-b RPC"
  statements = [
    "Define tenancy AccountA as ${var.account_a_tenancy_id}",
    "Define group AccountAGroup as ${var.account_a_group_id}",
    "Admit group AccountAGroup of tenancy AccountA to manage remote-peering-to in ${local.policy_scope}",
  ]
}

resource "oci_core_remote_peering_connection" "account_a" {
  compartment_id = var.compartment_id
  drg_id         = oci_core_drg.k8s_b_drg.id
  display_name   = "k8s-account-a"
}
