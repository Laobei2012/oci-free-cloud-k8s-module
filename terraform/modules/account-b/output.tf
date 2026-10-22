output "node_private_ips" {
  value = oci_core_instance.node[*].private_ip
}

# set as account_b_rpc_id of the module account-a
output "rpc_id" {
  value = oci_core_remote_peering_connection.account_a.id
}
