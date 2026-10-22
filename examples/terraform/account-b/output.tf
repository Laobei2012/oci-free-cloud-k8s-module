output "node_private_ips" {
  value = module.account_b.node_private_ips
}

# set as account_b_rpc_id in terraform/accounts/a
output "rpc_id" {
  value = module.account_b.rpc_id
}
