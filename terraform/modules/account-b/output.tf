output "node_private_ips" {
  value = oci_core_instance.node[*].private_ip
}

# set as account_b_rpc_id of the module account-a. Null in the region of account A
output "rpc_id" {
  value = one(oci_core_remote_peering_connection.account_a[*].id)
}

# set as account_b_lpg_id of the module account-a. Null in another region than account A
output "lpg_id" {
  value = one(oci_core_local_peering_gateway.account_a[*].id)
}

# the zones of the account B nodes are <zone_prefix>-AD-1 to -AD-3.
# set as oci_zone_prefix_b in cluster-vars
output "zone_prefix" {
  value = local.zone_prefix
}
