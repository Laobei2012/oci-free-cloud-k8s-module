provider "github" {
  owner = var.gh_org
  token = var.gh_token
}

resource "helm_release" "flux_operator" {
  depends_on = [kubernetes_namespace.flux_system]

  name       = "flux-operator"
  namespace  = kubernetes_namespace.flux_system.id
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-operator"
  wait       = true

  // The flux-addons Kustomization creates this Secret with the Web UI login configuration.
  values = [<<YAML
web:
  enabled: true
  configSecretName: flux-web-config
YAML
  ]
}

resource "kubernetes_secret" "git_auth" {
  depends_on = [kubernetes_namespace.flux_system]

  metadata {
    name      = "flux-instance-config"
    namespace = kubernetes_namespace.flux_system.id
  }

  data = {
    username                = null
    password                = null
    githubAppID             = "${var.github_app_id}"
    githubAppInstallationID = "${var.github_app_installation_id}"
    githubAppPrivateKey     = "${var.github_app_pem}"
  }

  type = "Opaque"
}

// Configure the Flux instance.
resource "helm_release" "flux_instance" {
  depends_on = [helm_release.flux_operator]

  name       = "flux"
  namespace  = kubernetes_namespace.flux_system.id
  repository = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  chart      = "flux-instance"

  values = [<<YAML
instance:
  distribution:
    version: ${var.flux_version}
    registry: ${var.flux_registry}
  components:
    - source-controller
    - kustomize-controller
    - helm-controller
    - notification-controller
    - image-automation-controller
    - image-reflector-controller
  sync:
    kind: GitRepository
    url: https://github.com/${var.gh_org}/${var.gh_repository}.git
    path: gitops/clusters/oci
    ref: "refs/heads/main"
    provider: github
    pullSecret: flux-instance-config
  # A new Git revision stops a running health check, so a fix does not wait
  # for the timeout of the broken revision. A second --feature-gates flag
  # adds to the gates that the operator sets, it does not replace them.
  kustomize:
    patches:
      - target:
          kind: Deployment
          name: kustomize-controller
        patch: |
          - op: add
            path: /spec/template/spec/containers/0/args/-
            value: --feature-gates=CancelHealthCheckOnNewRevision=true
YAML
  ]
}
