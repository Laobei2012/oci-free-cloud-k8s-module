variable "compartment_id" {
  type        = string
  description = "The compartment to create the resources in"
}

variable "region" {
  description = "OCI region"
  type        = string
}

variable "vault_id" {
  description = "OCI Vault OIDC"
  type        = string
}

variable "vault_key_id" {
  description = "OCI Vault encryption key OCID"
  type        = string
  default     = null
}

variable "tenancy_id" {
  description = "Tenancy OCID"
  type        = string
}

variable "github_app_id" {
  description = "GitHub App ID"
  type        = string
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
}


variable "email" {
  type        = string
  description = "email"
}

variable "gh_org" {
  type = string
}

variable "gh_repository" {
  description = "The live repository that Flux syncs, in the GitHub organization gh_org"
  type        = string
  default     = "oci-free-cloud-k8s"
}

variable "cluster_domain" {
  type        = string
  description = "Base domain of the cluster. Must match cluster_domain in the cluster-vars ConfigMap of the live repository"
}
