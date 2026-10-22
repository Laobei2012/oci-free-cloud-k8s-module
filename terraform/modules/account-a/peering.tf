# Peering to the VCN of account B (other tenancy). If both accounts have the
# same home region, the VCNs peer with local peering gateways (LPG). Else they
# peer with remote peering connections (RPC) on a DRG.
# Account A is the requestor and connects to the RPC or LPG of account B,
# see terraform/modules/account-b/peering.tf
locals {
  same_region = var.account_b_region == var.region
  # route target for the account B VCN
  account_b_gateway_id = local.same_region ? oci_core_local_peering_gateway.account_b[0].id : oci_core_drg_attachment.k8s_vcn[0].drg_id
  account_b_route_rules = [{
    destination       = var.account_b_vcn_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = local.same_region ? oci_core_local_peering_gateway.account_b[0].id : "drg"
    description       = "account B worker nodes"
  }]
  policy_scope = var.compartment_id == var.tenancy_id ? "tenancy" : "compartment id ${var.compartment_id}"
}

moved {
  from = oci_core_drg.k8s_drg
  to   = oci_core_drg.k8s_drg[0]
}

moved {
  from = oci_core_drg_attachment.k8s_vcn
  to   = oci_core_drg_attachment.k8s_vcn[0]
}

moved {
  from = oci_core_remote_peering_connection.account_b
  to   = oci_core_remote_peering_connection.account_b[0]
}

resource "oci_core_drg" "k8s_drg" {
  count          = local.same_region ? 0 : 1
  compartment_id = var.compartment_id
  display_name   = "k8s-drg"
}

resource "oci_core_drg_attachment" "k8s_vcn" {
  count        = local.same_region ? 0 : 1
  drg_id       = oci_core_drg.k8s_drg[0].id
  display_name = "k8s-vcn"

  network_details {
    id   = module.vcn.vcn_id
    type = "VCN"
  }
}

# the vcn module ignores changes to the route rules of its internet gateway
# route table, so the public subnet gets its own route table
resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_id
  vcn_id         = module.vcn.vcn_id
  display_name   = "k8s-public-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = module.vcn.internet_gateway_id
    description       = "Internet Gateway as default gateway for IPv4 destinations"
  }

  route_rules {
    destination       = var.account_b_vcn_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = local.account_b_gateway_id
    description       = "account B worker nodes"
  }
}

resource "oci_core_remote_peering_connection" "account_b" {
  count            = local.same_region ? 0 : 1
  compartment_id   = var.compartment_id
  drg_id           = oci_core_drg.k8s_drg[0].id
  display_name     = "k8s-account-b"
  peer_id          = var.account_b_rpc_id
  peer_region_name = var.account_b_rpc_id == null ? null : var.account_b_region

  depends_on = [oci_identity_policy.account_b_peering]
}

resource "oci_core_local_peering_gateway" "account_b" {
  count          = local.same_region ? 1 : 0
  compartment_id = var.compartment_id
  vcn_id         = module.vcn.vcn_id
  display_name   = "k8s-account-b"
  peer_id        = var.account_b_lpg_id

  depends_on = [oci_identity_policy.account_b_peering]
}

# requestor policy, account B admits the same group.
# for an RPC, the requestor tenancy must also be subscribed to the region of account B
resource "oci_identity_policy" "account_b_peering" {
  compartment_id = var.tenancy_id
  name           = local.same_region ? "endorse-account-b-local-peering" : "endorse-account-b-remote-peering"
  description    = local.same_region ? "Allows the k8s LPG to connect to the LPG of account B" : "Allows the k8s DRG to connect to the RPC of account B"
  statements = local.same_region ? [
    "Define tenancy AccountB as ${var.account_b_tenancy_id}",
    "Endorse group ${var.group_name} to manage local-peering-to in tenancy AccountB",
    "Endorse group ${var.group_name} to associate local-peering-gateways in ${local.policy_scope} with local-peering-gateways in tenancy AccountB",
    ] : [
    "Define tenancy AccountB as ${var.account_b_tenancy_id}",
    "Endorse group ${var.group_name} to manage remote-peering-to in tenancy AccountB",
  ]
}
