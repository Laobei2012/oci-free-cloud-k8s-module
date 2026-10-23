variable "gh_token" {
  sensitive = true
  type      = string
}

variable "gh_org" {
  type = string
}

variable "gh_repository" {
  type = string

  default = "oci-free-cloud-k8s"
}

variable "compartment_id" {
  type        = string
  description = "The compartment to create the resources in"
}

variable "vault_id" {
  type        = string
  description = "The OCID of the Vault to store the secrets in"
}

variable "vault_key_id" {
  type        = string
  description = "The OCID of the Vault encryption key to use when creating secrets"
  default     = null
}

variable "github_app_id" {
  description = "GitHub App ID"
  type        = string
  default     = ""
}

variable "github_app_installation_id" {
  description = "GitHub App Installation ID"
  type        = string
  default     = ""
}

variable "github_app_pem" {
  description = "The contents of the GitHub App private key PEM file"
  sensitive   = true
  type        = string
  default     = ""
}

variable "flux_version" {
  description = "Flux version semver range"
  type        = string
  default     = "2.x"
}

variable "flux_registry" {
  description = "Flux distribution registry"
  type        = string
  default     = "ghcr.io/fluxcd"
}

variable "cluster_domain" {
  type        = string
  description = "Base domain of the cluster"
}
