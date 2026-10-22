# Peering to the k8s VCN of account A (other tenancy). If both accounts have
# the same home region, the VCNs peer with local peering gateways (LPG). Else
# they peer with remote peering connections (RPC) on a DRG.
# Account A is the requestor, account B admits it, see terraform/modules/account-a/peering.tf
locals {
  same_region = var.account_a_region == var.region
  # route target for the account A VCN
  account_a_route_target = local.same_region ? oci_core_local_peering_gateway.account_a[0].id : "drg"
  policy_scope           = var.compartment_id == var.tenancy_id ? "tenancy" : "compartment id ${var.compartment_id}"
}

moved {
  from = oci_core_drg.k8s_b_drg
  to   = oci_core_drg.k8s_b_drg[0]
}

moved {
  from = oci_core_drg_attachment.k8s_b_vcn
  to   = oci_core_drg_attachment.k8s_b_vcn[0]
}

moved {
  from = oci_core_remote_peering_connection.account_a
  to   = oci_core_remote_peering_connection.account_a[0]
}

resource "oci_core_drg" "k8s_b_drg" {
  count          = local.same_region ? 0 : 1
  compartment_id = var.compartment_id
  display_name   = "k8s-b-drg"
}

resource "oci_core_drg_attachment" "k8s_b_vcn" {
  count        = local.same_region ? 0 : 1
  drg_id       = oci_core_drg.k8s_b_drg[0].id
  display_name = "k8s-b-vcn"

  network_details {
    id   = module.vcn.vcn_id
    type = "VCN"
  }
}

# acceptor policy, account A endorses the same group
resource "oci_identity_policy" "account_a_peering" {
  compartment_id = var.tenancy_id
  name           = local.same_region ? "admit-account-a-local-peering" : "admit-account-a-remote-peering"
  description    = local.same_region ? "Allows account A to connect its k8s LPG to the k8s-b LPG" : "Allows account A to connect its k8s DRG to the k8s-b RPC"
  statements = local.same_region ? [
    "Define tenancy AccountA as ${var.account_a_tenancy_id}",
    "Define group AccountAGroup as ${var.account_a_group_id}",
    "Admit group AccountAGroup of tenancy AccountA to manage local-peering-to in ${local.policy_scope}",
    "Admit group AccountAGroup of tenancy AccountA to associate local-peering-gateways in tenancy AccountA with local-peering-gateways in ${local.policy_scope}",
    ] : [
    "Define tenancy AccountA as ${var.account_a_tenancy_id}",
    "Define group AccountAGroup as ${var.account_a_group_id}",
    "Admit group AccountAGroup of tenancy AccountA to manage remote-peering-to in ${local.policy_scope}",
  ]
}

resource "oci_core_remote_peering_connection" "account_a" {
  count          = local.same_region ? 0 : 1
  compartment_id = var.compartment_id
  drg_id         = oci_core_drg.k8s_b_drg[0].id
  display_name   = "k8s-account-a"
}

resource "oci_core_local_peering_gateway" "account_a" {
  count          = local.same_region ? 1 : 0
  compartment_id = var.compartment_id
  vcn_id         = module.vcn.vcn_id
  display_name   = "k8s-account-a"
}
