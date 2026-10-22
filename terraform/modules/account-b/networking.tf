module "vcn" {
  source                  = "oracle-terraform-modules/vcn/oci"
  version                 = "4.0.0"
  compartment_id          = var.compartment_id
  tenancy_id              = var.tenancy_id
  region                  = var.region
  local_peering_gateways  = null
  vcn_name                = "k8s-b-vcn"
  vcn_dns_label           = "k8sbvcn"
  vcn_cidrs               = [var.vcn_cidr]
  create_internet_gateway = false
  create_nat_gateway      = true
  create_service_gateway  = false
  attached_drg_id         = local.same_region ? null : oci_core_drg_attachment.k8s_b_vcn[0].drg_id
  nat_gateway_route_rules = [{
    destination       = var.account_a_vcn_cidr
    destination_type  = "CIDR_BLOCK"
    network_entity_id = local.account_a_route_target
    description       = "k8s cluster in account A"
  }]
}

resource "oci_core_subnet" "nodes" {
  compartment_id             = var.compartment_id
  vcn_id                     = module.vcn.vcn_id
  cidr_block                 = cidrsubnet(var.vcn_cidr, 8, 1)
  route_table_id             = module.vcn.nat_route_id
  security_list_ids          = [oci_core_security_list.nodes.id]
  display_name               = "k8s-b-node-subnet"
  dns_label                  = "nodes"
  prohibit_public_ip_on_vnic = true
}

resource "oci_core_security_list" "nodes" {
  compartment_id = var.compartment_id
  vcn_id         = module.vcn.vcn_id
  display_name   = "k8s-b-node-subnet-sl"

  # egress everywhere
  egress_security_rules {
    stateless        = false
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
  }

  # ingress only from our cidr
  ingress_security_rules {
    stateless   = false
    source      = var.vcn_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "all"
  }

  # ingress from the cluster vcn in account A
  ingress_security_rules {
    stateless   = false
    source      = var.account_a_vcn_cidr
    source_type = "CIDR_BLOCK"
    protocol    = "all"
  }
}
