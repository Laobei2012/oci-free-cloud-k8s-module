locals {
  k8s_available_versions = jsonencode(data.oci_containerengine_node_pool_option.node_pool_options.kubernetes_versions)
  available_oke_images   = jsonencode(data.oci_containerengine_node_pool_option.node_pool_options.sources)
  k8s_version            = jsondecode(data.jq_query.latest_k8s_version.result)
  node_pool_image_id     = jsondecode(data.jq_query.latest_image.result)
}

data "oci_containerengine_node_pool_option" "node_pool_options" {
  node_pool_option_id = "all"
  compartment_id      = var.compartment_id
}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_id
}

# https://docs.oracle.com/en-us/iaas/Content/ContEng/Concepts/contengaboutk8sversions.htm
data "jq_query" "latest_k8s_version" {
  data  = local.k8s_available_versions
  query = ". | last"
}

# the API returns the images in no fixed order, so select Oracle Linux 9
# explicitly and take the last name, which has the newest build date
data "jq_query" "latest_image" {
  data  = local.available_oke_images
  query = "[.[] | select(.source_name | test(\"^Oracle-Linux-9\\\\..*-aarch64-.*-OKE-${replace(local.k8s_version, "v", "")}-\")?)] | sort_by(.source_name) | last | .image_id"
}


resource "oci_containerengine_cluster" "k8s_cluster" {
  compartment_id     = var.compartment_id
  kubernetes_version = local.k8s_version
  name               = "k8s-cluster"
  vcn_id             = module.vcn.vcn_id

  # 	cluster_pod_network_options {
  # 	cni_type = "OCI_VCN_IP_NATIVE"
  # }

  endpoint_config {
    is_public_ip_enabled = true
    subnet_id            = oci_core_subnet.vcn_public_subnet.id
  }
  options {
    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }
    kubernetes_network_config {
      pods_cidr     = "10.244.0.0/16"
      services_cidr = "10.96.0.0/16"
    }
    service_lb_subnet_ids = [oci_core_subnet.vcn_public_subnet.id]
  }
}

data "oci_containerengine_cluster_kube_config" "k8s_cluster_kube_config" {
  #Required
  cluster_id = oci_containerengine_cluster.k8s_cluster.id
}

resource "local_file" "kube_config" {
  depends_on = [oci_containerengine_node_pool.k8s_node_pool]
  # OKE generates the token command without a profile, add it
  content = replace(
    data.oci_containerengine_cluster_kube_config.k8s_cluster_kube_config.content,
    "      - generate-token\n",
    "      - generate-token\n      - --profile\n      - ${var.oci_config_profile}\n"
  )
  filename        = var.kubeconfig_path
  file_permission = 0400
}

resource "oci_containerengine_node_pool" "k8s_node_pool" {
  cluster_id         = oci_containerengine_cluster.k8s_cluster.id
  compartment_id     = var.compartment_id
  kubernetes_version = local.k8s_version
  name               = "k8s-node-pool"

  node_metadata = {
    user_data = base64encode(file("${path.module}/files/node-pool-init.sh"))
  }

  node_config_details {
    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
      subnet_id           = oci_core_subnet.vcn_private_subnet.id
    }

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[1].name
      subnet_id           = oci_core_subnet.vcn_private_subnet.id
    }

    placement_configs {
      availability_domain = data.oci_identity_availability_domains.ads.availability_domains[2].name
      subnet_id           = oci_core_subnet.vcn_private_subnet.id
    }

    size = var.kubernetes_worker_nodes
  }

  node_shape = "VM.Standard.A1.Flex"

  node_shape_config {
    memory_in_gbs = var.node_memory_in_gbs
    ocpus         = var.node_ocpus
  }
  node_source_details {
    image_id    = jsondecode(data.jq_query.latest_image.result)
    source_type = "image"

    boot_volume_size_in_gbs = var.node_boot_volume_size_in_gbs
  }
  initial_node_labels {
    key   = "name"
    value = "k8s-cluster"
  }
  # longhorn creates default disks only on labeled nodes, see gitops/infrastructure/longhorn
  initial_node_labels {
    key   = "node.longhorn.io/create-default-disk"
    value = "true"
  }
  ssh_public_key = var.ssh_public_key
}
