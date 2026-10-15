variable "compartment_id" {
  type        = string
  description = "The compartment to create the resources in"
}

variable "region" {
  description = "OCI region"
  type        = string

  default = "eu-frankfurt-1"
}

variable "public_subnet_id" {
  type        = string
  description = "The public subnet's OCID"
}

variable "node_pool_id" {
  description = "The OCID of the Node Pool where the compute instances reside"
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

variable "gh_token" {
  description = "Github PAT for FluxCD"
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

variable "github_app_pem" {
  description = "The contents of the GitHub App private key PEM file"
  sensitive   = true
  type        = string
}

variable "cluster_domain" {
  type        = string
  description = "Base domain of the cluster. Must match cluster_domain in gitops/core/cluster-vars.yaml"

  default = "nce.wtf"
}

variable "email" {
  type        = string
  description = "Email of the OCI user for external secrets"

  default = "770135+nce@users.noreply.github.com"
}

variable "gh_org" {
  type        = string
  description = "GitHub owner of the repository that Flux syncs"

  default = "nce"
}

variable "gh_repository" {
  type        = string
  description = "GitHub repository that Flux syncs"

  default = "oci-free-cloud-k8s"
}
