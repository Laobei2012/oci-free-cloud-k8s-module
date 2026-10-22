variable "tenancy_id" {
  description = "Tenancy OCID"
  type        = string
}

variable "repository" {
  description = "The GitHub repository that runs terraform, as owner/name"
  type        = string
}

variable "subject_prefix" {
  description = "The start of the sub claim of the GitHub token, before ':pull_request'. A repository with immutable subjects uses repo:<owner>@<owner_id>/<name>@<repo_id>, see 'gh api repos/<owner>/<name>/actions/oidc/customization/sub'"
  type        = string
}

variable "admin_group_name" {
  description = "The group of the apply user, it needs to manage all resources of the stack"
  type        = string
  default     = "Administrators"
}

variable "plan_permissions" {
  description = "The permissions of the plan user, the part of each policy statement after 'to'"
  type        = list(string)
}
