# Bootstrap token for the kubelet TLS bootstrap of the account B nodes.
# The extra group reuses the kubeadm RBAC bindings that OKE ships,
# which allow the token to create node CSRs and auto-approve them.
resource "random_string" "token_id" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "token_secret" {
  length  = 16
  special = false
  upper   = false
}

resource "kubernetes_secret_v1" "bootstrap_token" {
  metadata {
    name      = "bootstrap-token-${random_string.token_id.result}"
    namespace = "kube-system"
  }

  type = "bootstrap.kubernetes.io/token"

  data = {
    "token-id"                       = random_string.token_id.result
    "token-secret"                   = random_string.token_secret.result
    "usage-bootstrap-authentication" = "true"
    "auth-extra-groups"              = "system:bootstrappers:kubeadm:default-node-token"
    "description"                    = "kubelet bootstrap for the account B nodes (terraform/infra-b)"
  }
}
