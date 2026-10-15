module "externalsecrets" {
  source = "./modules/external-secrets"

  compartment_id = var.compartment_id
  tenancy_id     = var.tenancy_id
  vault_id       = var.vault_id
  vault_key_id   = var.vault_key_id
  region         = var.region
  email          = var.email

  depends_on = [
    module.fluxcd
  ]
}

module "fluxcd" {
  source = "./modules/fluxcd"

  gh_org                     = var.gh_org
  gh_repository              = var.gh_repository
  cluster_domain             = var.cluster_domain
  lb_security_group_id       = module.ingress.lb_security_group_id
  gh_token                   = var.gh_token
  compartment_id             = var.compartment_id
  github_app_id              = var.github_app_id
  github_app_installation_id = var.github_app_installation_id
  github_app_pem             = var.github_app_pem
}

module "ingress" {
  source = "./modules/ingress"

  compartment_id = var.compartment_id
}

module "grafana" {
  source = "./modules/grafana"

  compartment_id = var.compartment_id
}
