# Modules
This folder has the Terraform modules. A module has no backend and no provider configuration. The root modules in the live repository add them. [examples/terraform](../examples/terraform/) has one root module for each stack.

| Module | Stack in the live repository | Content |
| --- | --- | --- |
| [account-a](modules/account-a/) | `terraform/accounts/a` | The network, the peering, the OKE cluster, and node pool A in account A. It also writes the kubeconfig to `kubeconfig_path`. |
| [account-b](modules/account-b/) | `terraform/accounts/b` | The network, the peering, the worker nodes, and the cost reports in account B. |
| [cluster](modules/cluster/) | `terraform/clusters/oci` | Everything that needs the Kubernetes API, for example Flux and external-secrets. |
| [github-oidc](modules/github-oidc/) | `terraform/github-oidc/a` and `b` | The GitHub Actions login of one account. [modules/github-oidc/README.md](modules/github-oidc/README.md) explains it. |

Each stack has its own state. Apply the stacks in this order: `accounts/a`, `accounts/b`, and then `clusters/oci`.

The split keeps each Terraform run short and keeps the Kubernetes providers out of the account stacks. The submodules in `modules/cluster/modules` are only for the module `cluster`.

The submodule `cluster/modules/fluxcd` configures the `github` provider itself, with the token from the vault. So a root module cannot use `count`, `for_each` or `depends_on` on the module `cluster`.

## Use a module
In a root module of the live repository, pin the module to a release tag:

```
module "account_a" {
  source = "git::https://github.com/Laobei2012/oci-free-cloud-k8s-module.git//terraform/modules/account-a?ref=v0.1.0"
  ...
}
```

Use the same tag as the `GitRepository` `platform` of Flux, see [examples/gitops](../examples/gitops/).

The module `account-b` gets the cluster version, the private endpoint, and the CA of the cluster as variables. The example root module reads them from the state of `accounts/a` with `terraform_remote_state`.

## Vault secrets
The module `cluster` reads two secrets from the OCI vault `vault_id`, see [modules/cluster/secrets.tf](modules/cluster/secrets.tf):

| Vault secret | Content |
| --- | --- |
| `terraform-gh-token` | The GitHub PAT for FluxCD |
| `terraform-github-app-pem` | The private key of the GitHub App, in PEM format |

Create them before the first apply. Run this command with the `compartment_id`, `vault_id` and `vault_key_id` of the stack `clusters/oci`:

```
oci vault secret create-base64 --compartment-id <compartment_id> --vault-id <vault_id> --key-id <vault_key_id> \
  --secret-name terraform-gh-token --secret-content-content "$(printf '%s' '<token>' | base64)"
```

To change a secret, add a new version with `oci vault secret update-base64 --secret-id <id> --secret-content-content ...`.

## Kubeconfig
The module `account-a` writes the kubeconfig. It has no credentials, because the `oci` CLI makes the token. The stacks `accounts/b` and `clusters/oci` use the same file in their Kubernetes providers.
