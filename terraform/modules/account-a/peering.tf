# Remote peering to the VCN of account B (other tenancy, other region).
# Account A is the requestor and connects the RPC below to the RPC of
# account B, see terraform/modules/account-b/peering.tf
locals {
  account_b_route_rules = [{
    destination       = var.account_b_vcn_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = "drg"
    description       = "account B worker nodes"
  }]
  policy_scope = var.compartment_id == var.tenancy_id ? "tenancy" : "compartment id ${var.compartment_id}"
}

resource "oci_core_drg" "k8s_drg" {
  compartment_id = var.compartment_id
  display_name   = "k8s-drg"
}

resource "oci_core_drg_attachment" "k8s_vcn" {
  drg_id       = oci_core_drg.k8s_drg.id
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
    network_entity_id = oci_core_drg_attachment.k8s_vcn.drg_id
    description       = "account B worker nodes"
  }
}

resource "oci_core_remote_peering_connection" "account_b" {
  compartment_id   = var.compartment_id
  drg_id           = oci_core_drg.k8s_drg.id
  display_name     = "k8s-account-b"
  peer_id          = var.account_b_rpc_id
  peer_region_name = var.account_b_rpc_id == null ? null : var.account_b_region

  depends_on = [oci_identity_policy.account_b_peering]
}

# requestor policy, account B admits the same group.
# the requestor tenancy must also be subscribed to the region of account B
resource "oci_identity_policy" "account_b_peering" {
  compartment_id = var.tenancy_id
  name           = "endorse-account-b-remote-peering"
  description    = "Allows the k8s DRG to connect to the RPC of account B"
  statements = [
    "Define tenancy AccountB as ${var.account_b_tenancy_id}",
    "Endorse group ${var.group_name} to manage remote-peering-to in tenancy AccountB",
  ]
}
