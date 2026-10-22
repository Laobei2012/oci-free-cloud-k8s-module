# GitHub Actions logs in to this tenancy with its OIDC token. The token
# exchange endpoint of the identity domain trades the token for a session
# token (UPST) of one of two service users:
# - plan: pull requests, read-only
# - apply: the main branch, member of the admin group
# See .github/scripts/oci-session.sh for the exchange.

data "oci_identity_domains" "default" {
  compartment_id = var.tenancy_id
  display_name   = "Default"
}

locals {
  idcs_endpoint = trimsuffix(one(data.oci_identity_domains.default.domains).url, ":443")

  users = {
    plan  = "github-terraform-plan"
    apply = "github-terraform-apply"
  }

  # the sub claim of the GitHub token selects the service user
  subjects = {
    plan  = "${var.subject_prefix}:pull_request"
    apply = "${var.subject_prefix}:ref:refs/heads/main"
  }
}

resource "oci_identity_domains_user" "github" {
  for_each = local.users

  idcs_endpoint = local.idcs_endpoint
  user_name     = each.value
  description   = "GitHub Actions terraform ${each.key} for ${var.repository}"
  active        = true
  schemas = [
    "urn:ietf:params:scim:schemas:core:2.0:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:capabilities:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User",
  ]
  # without this list, the API does not return serviceUser and every plan shows a change
  attributes = join(",", [
    "id", "ocid", "userName", "active", "schemas", "description",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:capabilities:User",
    "urn:ietf:params:scim:schemas:oracle:idcs:extension:user:User.serviceUser",
  ])

  # a service user has no password and no keys, it only gets session tokens
  urnietfparamsscimschemasoracleidcsextensioncapabilities_user {
    can_use_api_keys                 = false
    can_use_auth_tokens              = false
    can_use_console_password         = false
    can_use_customer_secret_keys     = false
    can_use_db_credentials           = false
    can_use_oauth2client_credentials = false
    can_use_smtp_credentials         = false
  }

  urnietfparamsscimschemasoracleidcsextensionuser_user {
    service_user = true
  }

  # the API adds the userState and OCITags schemas
  lifecycle {
    ignore_changes = [schemas]
  }
}

# the confidential app that calls the token exchange endpoint, its
# client_id:client_secret is the only GitHub secret for this tenancy
resource "oci_identity_domains_app" "github" {
  idcs_endpoint = local.idcs_endpoint
  display_name  = "github-terraform"
  description   = "GitHub Actions token exchange for ${var.repository}"
  active        = true
  schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:App"]

  based_on_template {
    value         = "CustomWebAppTemplateId"
    well_known_id = "CustomWebAppTemplateId"
  }

  is_oauth_client    = true
  client_type        = "confidential"
  client_ip_checking = "anywhere"
  trust_scope        = "Explicit"
  allowed_grants = [
    "urn:ietf:params:oauth:grant-type:jwt-bearer",
    "client_credentials",
  ]

  # the API adds the OCITags schema
  lifecycle {
    ignore_changes = [schemas]
  }
}

resource "oci_identity_domains_identity_propagation_trust" "github" {
  idcs_endpoint = local.idcs_endpoint
  name          = "github-actions"
  description   = "GitHub Actions OIDC tokens of ${var.repository}"
  schemas       = ["urn:ietf:params:scim:schemas:oracle:idcs:IdentityPropagationTrust"]
  type          = "JWT"
  active        = true

  issuer              = "https://token.actions.githubusercontent.com"
  public_key_endpoint = "https://token.actions.githubusercontent.com/.well-known/jwks"
  oauth_clients       = [oci_identity_domains_app.github.name]

  subject_claim_name  = "sub"
  subject_type        = "User"
  allow_impersonation = true

  # the first rule that matches wins, a token that matches no rule gets no session
  dynamic "impersonation_service_users" {
    for_each = local.subjects
    content {
      rule  = "sub eq ${impersonation_service_users.value}"
      value = oci_identity_domains_user.github[impersonation_service_users.key].id
    }
  }

  # without this list, the API does not return the rules and every plan shows a change
  attributes = join(",", [
    "id", "name", "description", "schemas", "type", "active", "issuer",
    "publicKeyEndpoint", "oauthClients", "subjectClaimName", "subjectType",
    "allowImpersonation", "impersonationServiceUsers",
  ])
}

resource "oci_identity_group" "plan" {
  compartment_id = var.tenancy_id
  name           = "github-terraform-plan"
  description    = "GitHub Actions terraform plan, read-only"
}

resource "oci_identity_user_group_membership" "plan" {
  group_id = oci_identity_group.plan.id
  user_id  = oci_identity_domains_user.github["plan"].ocid
}

resource "oci_identity_policy" "plan" {
  compartment_id = var.tenancy_id
  name           = "github-terraform-plan"
  description    = "GitHub Actions terraform plan, read-only"
  statements     = [for permission in var.plan_permissions : "Allow group id ${oci_identity_group.plan.id} to ${permission}"]
}

data "oci_identity_groups" "admin" {
  compartment_id = var.tenancy_id
  name           = var.admin_group_name
}

resource "oci_identity_user_group_membership" "apply" {
  group_id = one(data.oci_identity_groups.admin.groups).id
  user_id  = oci_identity_domains_user.github["apply"].ocid
}
