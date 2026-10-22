# OCI free tier Kubernetes modules

This repository has Terraform modules and Flux apps for a Kubernetes cluster on
the Oracle Cloud [Always Free tier][oci-free-tier]. The cluster costs nothing per
month. It uses two free tier accounts to get four worker nodes.

You do not run Terraform or Flux from this repository. You run them from a
second, private repository: the live repository. The live repository holds your
own values and pins this repository to one release tag.

This repository is a fork of [nce/oci-free-cloud-k8s][upstream].
[README.legacy.md](README.legacy.md) has the original README, with background
notes and the history of Kubernetes upgrades.

[oci-free-tier]: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm
[upstream]: https://github.com/nce/oci-free-cloud-k8s

## What the modules make

| Part | Content |
| --- | --- |
| Account A | The OKE cluster in `us-phoenix-1`, and a node pool of two `VM.Standard.A1.Flex` nodes |
| Account B | Two more `VM.Standard.A1.Flex` nodes in `us-chicago-1`. They join the cluster through a remote peering connection. |
| Ingress | envoy-gateway with Gateway API on the free layer 7 load balancer. Teleport uses the free layer 4 load balancer. |
| Login | Dex with GitHub as the identity provider. `HTTPRoute` objects use OIDC through envoy-gateway. |
| GitOps | The Flux operator. A GitHub webhook starts a sync, and Flux writes the commit status to GitHub. |
| Storage | Longhorn, with one pool in each account |

All nodes are arm64. The free tier has no free x86 instances.

Oracle changed the free tier in June 2026. An account without a credit card
gets half of the resources. A pay-as-you-go account still gets 4 OCPUs and
24 GB of memory.

The cluster in account B is not supported by Oracle. The account B nodes join
with the kubelet TLS bootstrap and a bootstrap token. An OKE change can stop
this setup at any time. [README.legacy.md](README.legacy.md#worker-nodes-from-a-second-account)
explains the setup.

## Repository layout

| Path | Content |
| --- | --- |
| [terraform/modules](terraform/modules/) | The modules `account-a`, `account-b`, `cluster` and `github-oidc`. [terraform/README.md](terraform/README.md) describes them. |
| [gitops/infrastructure](gitops/infrastructure/) | cert-manager, cloudnative-pg, dex, envoy-gateway, external-dns, external-secrets, fluxcd-addons, kubelet-csr-approver, longhorn, metrics-server, snapshot-controller, teleport |
| [gitops/monitoring](gitops/monitoring/) | grafana, kube-prometheus-stack, loki, oci-cost |
| [gitops/tools](gitops/tools/) | jenkins |
| [gitops/platform](gitops/platform/) | The entry point for Flux. It lists the three folders above. |
| [examples](examples/) | The Terraform root modules and the Flux entry point of a live repository |

Each app folder has a `flux.yaml` with its own Flux `Kustomization`. All of them
read from the `GitRepository` named `platform`.

## How the two repositories work together

```
live repository (private)                 this repository (public)
-------------------------                 ------------------------
terraform/accounts/a     --- module ----> terraform/modules/account-a
terraform/accounts/b     --- module ----> terraform/modules/account-b
terraform/clusters/oci   --- module ----> terraform/modules/cluster
gitops/clusters/oci      --- Flux ------> gitops/platform
  cluster-vars.yaml        (one tag, for example v0.1.1)
  apps of your own
```

Terraform reads a module with a git source and a `?ref=` tag. Flux reads
`gitops/platform` with a `GitRepository` that has the same tag. Flux replaces
each `${name}` in the apps with the value from the ConfigMap `cluster-vars` of
the live repository.

## Requirements

- Two Oracle Cloud free tier accounts, A and B
- Terraform 1.12 or later, for the `oci` backend
- The `oci` CLI, with a profile for each account in `~/.oci/config`
- A domain in Cloudflare, for cert-manager and external-dns
- A GitHub organization, a GitHub App for Flux, and OAuth apps for Dex and Teleport

Account A must subscribe to the region `us-chicago-1`, because the requestor
of a remote peering must subscribe to the region of the acceptor. You cannot
remove a region subscription again.

## Set up a live repository

1. Create a private repository.
2. In account A, create a bucket for the Terraform states:
   ```
   oci os bucket create --name terraform-states --versioning Enabled --compartment-id <tenancy_id>
   ```
3. Copy `examples/terraform/account-a` to `terraform/accounts/a` in the live repository.
4. Copy `examples/terraform/account-b` to `terraform/accounts/b`.
5. Copy `examples/terraform/cluster` to `terraform/clusters/oci`.
6. In each `main.tf`, change the module `source` to the git URL in the comment above it.
7. In each stack, copy `backend.hcl.example` to `backend.hcl` and set your object storage namespace.
8. In each stack, copy `terraform.tfvars.example` to `terraform.tfvars` and set your values.
9. Create the vault secrets in the table below.
10. Apply `terraform/accounts/a`, then `terraform/accounts/b`, then `terraform/clusters/oci`.
11. Copy `examples/gitops/clusters/example` to `gitops/clusters/oci`, and set your values in `cluster-vars.yaml`.

Run each stack with these commands:

```
terraform init -backend-config=backend.hcl
terraform apply
```

The stack `accounts/a` writes the kubeconfig to `terraform/.kube.config`. The
other two stacks use this file. The file has no credentials, because the `oci`
CLI makes the token.

The peering of the two accounts needs two runs of `accounts/a`. The first run
makes the requestor in account A. Then `accounts/b` makes the acceptor and
outputs `rpc_id`. Set `account_b_rpc_id` in `accounts/a` to this value, and
apply `accounts/a` again. The output `account_b_peering_status` must be `PEERED`.

The module `cluster` installs the Flux operator. Flux then syncs
`gitops/clusters/oci` of the live repository. If the first apply of
`clusters/oci` fails on the `ClusterSecretStore`, wait until Flux installs
external-secrets, and apply again.

## Vault secrets

The module `cluster` creates an OCI vault store for external-secrets. You create
these secrets in the vault before the first apply:

| Vault secret | Read by |
| --- | --- |
| `terraform-gh-token` | The module `cluster`, for Flux |
| `terraform-github-app-pem` | The module `cluster`, for the GitHub App of Flux |
| `cloudflare-api-token` | cert-manager, external-dns |
| `GITHUB_DEX_CLIENT_ID`, `GITHUB_DEX_CLIENT_SECRET` | dex |
| `dex-envoy-client-secret` | dex, envoy-gateway, fluxcd-addons, longhorn, kube-prometheus-stack, jenkins |
| `dex-grafana-client` | dex, grafana |
| `fluxcd-github-token` | fluxcd-addons, for the commit status |
| `fluxcd-slack-webhook` | fluxcd-addons, the bot token of the Slack app |
| `SLACK_API_URL` | kube-prometheus-stack, the Alertmanager webhook |
| `PAGERDUTY_ROUTING_KEY` | kube-prometheus-stack |
| `teleport-github-client-secret` | teleport |

The cluster writes these secrets itself: `github-flux-webhook-token`,
`oci-cost-db-grafana`, and the `prometheus-remote-write-*` secrets.
[terraform/README.md](terraform/README.md#vault-secrets) shows the command that
creates a secret.

## Add your own apps

Put the apps that only your cluster needs in the live repository, for example
in `gitops/apps`. Their Flux `Kustomization` uses the `GitRepository`
`flux-system`, which is the live repository.

Jenkins reads its agents and jobs from the optional ConfigMap
`jenkins-site-values` in the namespace `jenkins`. Put your JCasC
`configScripts` in its key `values.yaml`. Give the ConfigMap the label
`reconcile.fluxcd.io/watch: Enabled`, so that a change starts a Helm upgrade.

## Update to a new release

Use the same tag in all module sources and in the `GitRepository` `platform`.
If the tags differ, Terraform and Flux run different versions of the code.

Renovate can update all tags in one pull request. Its terraform manager finds
the module sources. Its flux manager does not read the tag of a
`GitRepository`, so a regex manager finds it. Add this configuration to
`renovate.json` in the live repository:

```json
{
  "customManagers": [
    {
      "customType": "regex",
      "managerFilePatterns": ["/^gitops/clusters/.+/platform-source\\.yaml$/"],
      "matchStrings": [
        "url: https://github\\.com/(?<depName>\\S+?)(?:\\.git)?\\s+ref:\\s+tag: (?<currentValue>\\S+)"
      ],
      "datasourceTemplate": "github-tags"
    }
  ],
  "packageRules": [
    {
      "matchPackageNames": ["Laobei2012/oci-free-cloud-k8s-module"],
      "groupName": "oci-free-cloud-k8s-module"
    }
  ]
}
```

Before you apply a new release, read the `terraform plan` of each stack.

## Test a change before a release

1. Push the change to a branch of this repository.
2. In the live repository, set each module `?ref=` to the branch name.
3. Run `terraform init -upgrade` and `terraform plan` in each stack.
4. To test the apps, set `spec.ref.branch` in the `GitRepository` `platform` of the cluster.

CI runs on each pull request of this repository. It runs `terraform validate`
on the modules and the examples. It builds each Kustomization, replaces the
variables with the example values, and validates the result with kubeconform.
It also runs gitleaks.

## License

This repository and the upstream repository have no LICENSE file.
