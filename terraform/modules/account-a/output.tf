output "k8s_cluster_id" {
  value = oci_containerengine_cluster.k8s_cluster.id
}

output "compartment_id" {
  value = var.compartment_id
}

output "public_subnet_id" {
  value = oci_core_subnet.vcn_public_subnet.id
}

output "node_pool_id" {
  value = oci_containerengine_node_pool.k8s_node_pool.id
}

# the control plane version, the kubelets of account B must not be newer
output "k8s_version" {
  value = oci_containerengine_cluster.k8s_cluster.kubernetes_version
}

output "k8s_private_endpoint" {
  value = oci_containerengine_cluster.k8s_cluster.endpoints[0].private_endpoint
}

output "k8s_cluster_ca" {
  value = yamldecode(data.oci_containerengine_cluster_kube_config.k8s_cluster_kube_config.content).clusters[0].cluster["certificate-authority-data"]
}

output "account_b_peering_status" {
  value = local.same_region ? oci_core_local_peering_gateway.account_b[0].peering_status : oci_core_remote_peering_connection.account_b[0].peering_status
}

# the zones of the OKE nodes are <zone_prefix>-AD-1 to -AD-3.
# set as oci_zone_prefix_a in cluster-vars
output "zone_prefix" {
  value = one([for r in data.oci_identity_regions.all.regions : r.key if r.name == var.region])
}

data "oci_identity_regions" "all" {}
