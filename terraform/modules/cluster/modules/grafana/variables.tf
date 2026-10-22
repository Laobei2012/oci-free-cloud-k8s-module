variable "compartment_id" {
  type        = string
  description = "The compartment to create the resources in"
}

variable "tenancy_id" {
  type        = string
  description = "Tenancy OCID"
}

variable "vault_id" {
  type        = string
  description = "The OCID of the Vault to store the secrets in"
}

variable "vault_key_id" {
  type        = string
  description = "The OCID of the Vault encryption key to use when creating secrets"
}
