module "vcn" {
  source                  = "oracle-terraform-modules/vcn/oci"
  version                 = "4.0.0"
  compartment_id          = var.compartment_id
  tenancy_id              = var.tenancy_id
  region                  = var.region
  local_peering_gateways  = null
  attached_drg_id         = local.same_region ? null : oci_core_drg_attachment.k8s_vcn[0].drg_id
  nat_gateway_route_rules = local.account_b_route_rules
  vcn_name                = "k8s-vcn"
  vcn_dns_label           = "k8svcn"
  vcn_cidrs               = ["10.0.0.0/16"]
  create_internet_gateway = true
  create_nat_gateway      = true
  create_service_gateway  = true
}
