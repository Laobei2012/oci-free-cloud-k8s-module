mock_provider "oci" {
  override_data {
    target = data.oci_identity_regions.all
    values = {
      regions = [
        { key = "IAD", name = "us-ashburn-1" },
        { key = "SJC", name = "us-sanjose-1" },
      ]
    }
  }
  override_data {
    target = data.oci_identity_availability_domains.ads
    values = {
      availability_domains = [{ name = "xyz:IAD-AD-1" }, { name = "xyz:IAD-AD-2" }, { name = "xyz:IAD-AD-3" }]
    }
  }
  override_data {
    target = data.oci_containerengine_cluster_kube_config.k8s_cluster_kube_config
    values = {
      content = "clusters:\n- cluster:\n    certificate-authority-data: Y2E=\n"
    }
  }
}

override_resource {
  target = oci_containerengine_cluster.k8s_cluster
  values = {
    endpoints = [{ private_endpoint = "10.0.0.10:6443" }]
  }
}

mock_provider "jq" {
  override_data {
    target = data.jq_query.latest_k8s_version
    values = { result = "\"v1.37.0\"" }
  }
  override_data {
    target = data.jq_query.latest_image
    values = { result = "\"ocid1.image.oc1..example\"" }
  }
}

mock_provider "local" {}

override_data {
  target = module.vcn.data.oci_core_services.all_oci_services
  values = {
    services = [{ id = "ocid1.service.oc1..all", cidr_block = "all-phx-services-in-oracle-services-network" }]
  }
}

variables {
  kubeconfig_path              = "kubeconfig"
  compartment_id               = "ocid1.tenancy.oc1..a"
  tenancy_id                   = "ocid1.tenancy.oc1..a"
  region                       = "us-ashburn-1"
  ssh_public_key               = "ssh-ed25519 AAAA"
  node_memory_in_gbs           = 12
  node_ocpus                   = 2
  node_boot_volume_size_in_gbs = 75
}

run "no_account_b" {
  command = apply

  assert {
    condition     = length(oci_core_drg.k8s_drg) == 0 && length(oci_core_remote_peering_connection.account_b) == 0 && length(oci_core_local_peering_gateway.account_b) == 0 && length(oci_identity_policy.account_b_peering) == 0
    error_message = "Without account B, the module must make no peering resources."
  }

  assert {
    condition     = length(oci_core_route_table.public.route_rules) == 1
    error_message = "Without account B, the public route table must have only the internet route."
  }

  assert {
    condition     = length(oci_core_security_list.private_subnet_sl.ingress_security_rules) == 1 && length(oci_core_security_list.public_subnet_sl.ingress_security_rules) == 2
    error_message = "Without account B, the security lists must have no account B rules."
  }

  assert {
    condition     = output.zone_prefix == "IAD"
    error_message = "zone_prefix must be the region key."
  }
}

run "same_region" {
  command = apply

  variables {
    account_b_tenancy_id = "ocid1.tenancy.oc1..b"
    account_b_region     = "us-ashburn-1"
  }

  assert {
    condition     = length(oci_core_local_peering_gateway.account_b) == 1 && length(oci_core_drg.k8s_drg) == 0 && length(oci_core_remote_peering_connection.account_b) == 0
    error_message = "In the same region, the module must use an LPG and no DRG."
  }

  assert {
    condition     = oci_identity_policy.account_b_peering[0].name == "endorse-account-b-local-peering"
    error_message = "In the same region, the policy must endorse local peering."
  }

  assert {
    condition     = length(oci_core_route_table.public.route_rules) == 2
    error_message = "With account B, the public route table must have the account B route."
  }
}

run "other_region" {
  command = apply

  variables {
    account_b_tenancy_id = "ocid1.tenancy.oc1..b"
    account_b_region     = "us-sanjose-1"
  }

  assert {
    condition     = length(oci_core_drg.k8s_drg) == 1 && length(oci_core_remote_peering_connection.account_b) == 1 && length(oci_core_local_peering_gateway.account_b) == 0
    error_message = "In another region, the module must use a DRG and an RPC."
  }

  assert {
    condition     = oci_identity_policy.account_b_peering[0].name == "endorse-account-b-remote-peering"
    error_message = "In another region, the policy must endorse remote peering."
  }

  assert {
    condition     = length(oci_core_security_list.private_subnet_sl.ingress_security_rules) == 2
    error_message = "With account B, the private security list must admit the account B VCN."
  }
}

run "account_b_without_region" {
  command = plan

  variables {
    account_b_tenancy_id = "ocid1.tenancy.oc1..b"
  }

  expect_failures = [var.account_b_region]
}

run "one_availability_domain" {
  command = apply

  override_data {
    target = data.oci_identity_availability_domains.ads
    values = {
      availability_domains = [{ name = "xyz:SJC-AD-1" }]
    }
  }

  assert {
    condition     = length(oci_containerengine_node_pool.k8s_node_pool.node_config_details[0].placement_configs) == 1
    error_message = "In a region with one availability domain, the node pool must have one placement."
  }
}

run "three_availability_domains" {
  command = apply

  assert {
    condition     = length(oci_containerengine_node_pool.k8s_node_pool.node_config_details[0].placement_configs) == 3
    error_message = "In a region with three availability domains, the node pool must have three placements."
  }
}
