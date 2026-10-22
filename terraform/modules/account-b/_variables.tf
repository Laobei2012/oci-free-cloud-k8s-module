variable "k8s_version" {
  description = "Kubernetes version of the OKE control plane (output k8s_version of module account-a). The kubelets must not be newer"
  type        = string
}

variable "k8s_private_endpoint" {
  description = "Private endpoint of the OKE API server (output k8s_private_endpoint of module account-a)"
  type        = string
}

variable "k8s_cluster_ca" {
  description = "CA data of the OKE cluster (output k8s_cluster_ca of module account-a)"
  type        = string
}

variable "tenancy_id" {
  description = "Tenancy OCID of account B"
  type        = string
}

variable "compartment_id" {
  description = "The account B compartment to create the resources in"
  type        = string
}

variable "region" {
  description = "Home region of account B"
  type        = string
  default     = "us-chicago-1"
}

variable "ssh_public_key" {
  description = "SSH Public Key used to access all instances"
  type        = string
}

variable "vcn_cidr" {
  description = "CIDR of the account B VCN. Must match account_b_vcn_cidr of the module account-a"
  type        = string
  default     = "10.1.0.0/16"
}

variable "account_a_tenancy_id" {
  description = "Tenancy OCID of account A, which hosts the OKE cluster"
  type        = string
}

variable "account_a_group_id" {
  description = "OCID of the account A group that runs terraform for the module account-a (group_name there)"
  type        = string
}

variable "account_a_vcn_cidr" {
  description = "CIDR of the k8s VCN in account A"
  type        = string
  default     = "10.0.0.0/16"
}

variable "worker_nodes" {
  description = "Worker node count"
  type        = number
  default     = 2
}

variable "node_memory_in_gbs" {
  description = "Memory per worker node in GB"
  type        = number
  default     = 12
}

variable "node_ocpus" {
  description = "OCPUs per worker node"
  type        = number
  default     = 2
}

variable "node_boot_volume_size_in_gbs" {
  description = "Boot volume size per worker node in GB"
  type        = number
  default     = 75
}
