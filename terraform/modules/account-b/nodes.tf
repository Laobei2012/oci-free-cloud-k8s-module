locals {
  k8s_version = var.k8s_version
  # e.g. v1.36.4 -> v1.36
  k8s_minor = join(".", slice(split(".", local.k8s_version), 0, 2))
  # OKE labels its nodes with the region key, e.g. phx and PHX-AD-1
  region_key = one([for r in data.oci_identity_regions.all.regions : r.key if r.name == var.region])
  # in the same region as account A, the zones get a -B suffix, e.g. PHX-B-AD-1.
  # Longhorn keeps the volumes of each account in its zones, see gitops/infrastructure/longhorn
  zone_prefix = local.same_region ? "${local.region_key}-B" : local.region_key
}

data "oci_identity_regions" "all" {}

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.tenancy_id
}

data "oci_core_images" "oracle_linux" {
  compartment_id           = var.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "9"
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_core_instance" "node" {
  count               = var.worker_nodes
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[count.index % length(data.oci_identity_availability_domains.ads.availability_domains)].name
  compartment_id      = var.compartment_id
  display_name        = "k8s-b-node-${count.index}"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = var.node_ocpus
    memory_in_gbs = var.node_memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.nodes.id
    assign_public_ip = false
    hostname_label   = "k8s-b-node-${count.index}"
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.oracle_linux.images[0].id
    boot_volume_size_in_gbs = var.node_boot_volume_size_in_gbs
  }

  metadata = {
    ssh_authorized_keys = var.ssh_public_key
    user_data = base64encode(templatefile("${path.module}/files/node-init.sh.tftpl", {
      k8s_version     = trimprefix(local.k8s_version, "v")
      k8s_minor       = local.k8s_minor
      api_server      = "https://${var.k8s_private_endpoint}"
      cluster_ca      = var.k8s_cluster_ca
      bootstrap_token = "${random_string.token_id.result}.${random_string.token_secret.result}"
      topology_region = lower(local.region_key)
      topology_zone   = "${local.zone_prefix}-AD-${count.index % length(data.oci_identity_availability_domains.ads.availability_domains) + 1}"
    }))
  }

  # a new image or k8s version must not replace all nodes at once.
  # replace one node at a time, see README.md
  lifecycle {
    ignore_changes = [source_details[0].source_id, metadata]
  }

  depends_on = [
    kubernetes_secret_v1.bootstrap_token,
    oci_core_remote_peering_connection.account_a,
    oci_core_local_peering_gateway.account_a,
  ]
}
