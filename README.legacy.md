# ⎈ Oracle Cloud Kubernetes free tier setup

> [!NOTE]
> This is the README of the original repository, before the split into modules.
> It keeps the background notes and the upgrade history. [README.md](README.md)
> describes the current layout and setup.

> [!NOTE]
> **Free Tier Change: 06.2026**
>
> Oracle changed the free-tier specs. Free Tier Users with no Credit Card have the
> resouces halved. For PayAsYouGo Customers  nothing changed (4 oCPUs & 24GB Memory).

This repository leverages Oracle Cloud's [always free tier][oci-free-tier] to provision a kubernetes cluster.
In its current setup there are **no monthly costs** anymore, as I've now moved
the last part (DNS) from oci to cloudflare.

[oci-free-tier]: https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm

Oracle Kubernetes Engine (OKE) is free to use, and you only pay for worker
nodes _if_ you exceed the Always Free tier — which we don’t.
The free tier provides **4 oCPUs and 24GB of memory**, which are split between two
worker nodes (`VM.Standard.A1.Flex`), allowing for efficient resource
utilization. Each node has a 100GB boot volume, with around 60GB available for
in-cluster storage via Longhorn. For ingress, we use the `GatewayAPI` implementation
provided by envoy-gateway together with Oracle’s
Flexible Load Balancer (10Mbps; layer 7). For `teleport` we use the network LB (layer 4).
In this configuration both load balancers are free to use.

Getting an Always Free account can sometimes be tricky, but there are several
guides on Reddit that explain how to speed up the creation process.

The initial infra setup is inspired by this great tutorial: https://arnoldgalovics.com/free-kubernetes-oracle-cloud/

> [!WARNING]
> This project uses arm instances, no x86 architecture; due to limitations
> of the always free tier.
>
> *And please mind:*
> This setup is loosely documented and opinionated. It's working and in use
> by myself. It's public, to showcase how this setup can be recreated, but
> you need to know what you're doing and where to make modification for yourself.

This repo hosts my personal stuff and is a playground for my kubernetes tooling.

> [!TIP]
> In case you want to reproduce another `oke` setup, you might [find this guide](https://github.com/piontec/free-oci-kubernetes)
> also helpful.

## :wrench: Tooling

- [x] K8s control plane
- [x] Worker Nodes
- [x] Ingress with GatewayAPI
  * envoy-gateway on a layer 7 lb
  * teleport svc on a layer 4 lb
  * `httproutes` with oidc protection
- [x] Certmanager
  * with letsencrypt setup for cloudflare dns challenge
- [x] External DNS
  * with sync to the cloudflare dns management
  * CR to provide `A` records for my home-network
- [x] Dex as OIDC Provider
  * with github as idP
- [x] FluxCD for Gitops
  * deployed with the new fluxcd operator
  * github → flux webhook receiver for instant reconciliation
  * flux → github commit annotation about conciliation status
- [x] Teleport for k8s cluster access
- [x] Storage
   * with longhorn
- [x] Grafana with Dex Login
   * Dashboards for Flux
   * [ ] Switch to Grafana Operator
- [x] Loki for log aggregation
   * single binary on an account B node, 20Gi `longhorn-account-b` volume, 14 days of retention
   * an Alloy DaemonSet sends the container logs of each node
   * Grafana has the datasource `Loki`
- [x] Metrics Server for cpu/mem usage overview
- [ ] Kyverno and Image Signing
- [ ] One Slack bot token for Flux and Alertmanager
   * both read the token from one Vault key, for example `slack-bot-token`
   * Alertmanager posts with `chat.postMessage` to `${alertmanager_slack_channel_id}` from cluster-vars
   * invite the bot to `#monitoring`, then send a test alert to make sure that it arrives
   * then remove `SLACK_API_URL` from Vault and the incoming webhook from the Slack app

# :keyboard: Setup
> [!Note]
> I've recently updated the tf-backend config,  to utilizes the oci native
> backend now. This requires terraform >= v1.12

This setup uses terraform to manage the oci **and** a bit of the kubernetes part.

## Tooling on the client side

* terraform
* oci-binary
* `oci setup config` successfully run

The terraform state is pushed to oracle object storage (free as well). For that
we have to create a bucket initially:
```
❯ oci os bucket create --name terraform-states --versioning Enabled --compartment-id xxx
```

With the bucket created we can configure the `~/.oci/config`:
```
[DEFAULT]
user=ocid1.user.xxx
fingerprint=ee:f4:xxx
tenancy=ocid1.tenancy.oc1.xxx
region=us-phoenix-1
key_file=/Users/xxxx.pem

[default]
aws_access_key_id = xxx <- this needs to be created via UI: User -> customer secret key
aws_secret_access_key = xxx <- this needs to be created via UI: User -> customer secret key

```
Refer to the [backend config example](./examples/terraform/account-a/backend.hcl.example) for the terraform s3 configuration.

## 🏗️ Repository Layout
This repository holds the reusable code. Your own values and the Terraform runs are in a
second, private "live" repository. The live repository pins this repository to one release tag.

* [terraform/modules](terraform/modules/): the modules `account-a` (network, peering, OKE cluster,
  node pool A), `account-b` (network, peering, worker nodes in account B), `cluster` (everything that
  needs the Kubernetes API, for example Flux and external-secrets), and `github-oidc`.
* [examples/terraform](examples/terraform/): one root module for each stack. Copy each one to the
  live repository as `terraform/accounts/a`, `terraform/accounts/b` and `terraform/clusters/oci`, and
  change the module `source` to
  `git::https://github.com/Laobei2012/oci-free-cloud-k8s-module.git//terraform/modules/<name>?ref=<tag>`.
  The instructions below use these live folder names.
* [gitops](gitops/): the Flux apps. [examples/gitops](examples/gitops/) has the Flux entry point of the
  live repository, see below.

These components are independent from each other, but obv. the infra should
be created first.

For the config part, you need to add a private `*.tfvars` file:
```
compartment_id   = "ocid1.tenancy.zzz"
... # this list is currently not complete; there's more to add
```

Running the `config` section you need more variables, which either get output
by the `infra`-run or have to be extracted from the webui.

> [!TIP]
> During the initial provisioning the terraform run of `config` might fail,
> it's trying to create a `ClusterSecretStore` which only exist after the
> initial deployment of `external secrets` with flux. This is expected.
> Just rerun terraform after external secrets is successfully deployed.

## Worker nodes from a second account
A second free tier account (account B) adds 2 more `VM.Standard.A1.Flex`
worker nodes to the cluster. Account A hosts the OKE cluster in
`us-phoenix-1`. Account B runs the nodes in its home region `us-chicago-1`.
Terraform in `terraform/accounts/b` of the live repository manages account B,
with the module [account-b](terraform/modules/account-b/).

> [!WARNING]
> Oracle does not support this setup. The nodes join with the standard
> kubelet TLS bootstrap and a bootstrap token, not with the OKE node join.
> An OKE change can stop it at any time.

The setup has these parts:

* A remote peering connection connects the two VCNs. Account A is the
  requestor, account B admits it with an IAM policy.
* The nodes run Oracle Linux 9 with cri-o and a kubelet from `pkgs.k8s.io`.
  The kubelet version matches the cluster version.
* The kubelet uses the private API endpoint of the cluster.
* The nodes have the label `tenancy=account-b`. They are not load balancer
  backends, so Envoy does not run on them. See
  [Gateway API - Loadbalancer setup](#gateway-api---loadbalancer-setup).
* Longhorn has two pools, because synchronous replicas across regions are
  too slow. The StorageClass `longhorn` uses the OKE nodes. The
  StorageClass `longhorn-account-b` uses the account B nodes. A volume of
  `longhorn-account-b` holds approximately 25 GB of data at most.
* The account B nodes set the label `node.longhorn.io/create-default-disk`
  and the Longhorn tag `pool-b` on themselves. Longhorn does not put
  replicas of volumes without a node selector on nodes with a tag. So the
  volumes of the OKE nodes stay in account A.
* Pods that use a volume of `longhorn-account-b` run only in the zones of
  account B.
* Pods that use a volume of the StorageClass `longhorn` run only in the
  zones of account A. The StorageClass lists these zones in
  `allowedTopologies`, and Longhorn copies them into the node affinity of
  each new PV. If account A gets a new zone, add it in
  `gitops/infrastructure/longhorn/helm.yaml`.
* The OKE `csi-oci-node` pod runs on these nodes. But OCI block volumes of
  the StorageClasses `oci` and `oci-bv` cannot attach to them, because the
  instances are not in account A. This has no effect on Longhorn.

Prerequisites:

* An OCI CLI profile for account B in `~/.oci/config`. The default is
  `ACCOUNT_B` with an API key, which does not expire. A session token from
  `oci session authenticate` expires after 24 hours at most. Set
  `oci_config_profile` and `oci_auth` in the tfvars for a different profile.
* The `DEFAULT` profile is account A, which holds the state bucket.
* The OCID of the account A group that runs terraform, for example
  `Administrators`.
* Account A is subscribed to the region `us-chicago-1`. The requestor of a
  remote peering must be subscribed to the region of the acceptor. You
  cannot remove a region subscription again.

Do these steps in this order:

1. Add `account_b_tenancy_id` to the tfvars of `terraform/accounts/a`.
2. Run `terraform apply` in `terraform/accounts/a`. This creates the DRG, the
   peering connection of account A and the IAM policy.
3. Add a tfvars file to `terraform/accounts/b`:
   ```
   tenancy_id           = "ocid1.tenancy.oc1..accountb"
   compartment_id       = "ocid1.tenancy.oc1..accountb"
   account_a_tenancy_id = "ocid1.tenancy.oc1..accounta"
   account_a_group_id   = "ocid1.group.oc1..accounta"
   ssh_public_key       = "ssh-rsa AAAA..."
   ```
4. Run `terraform init` and `terraform apply` in `terraform/accounts/b`.
5. Set `account_b_rpc_id` in the tfvars of `terraform/accounts/a` to the output
   `rpc_id` of `terraform/accounts/b`.
6. Run `terraform apply` in `terraform/accounts/a`. The output
   `account_b_peering_status` must be `PEERED`.
7. Wait approximately 10 minutes and run `kubectl get nodes -l tenancy=account-b`.
8. Make sure that the serving certificates of the nodes are approved. The API
   server needs them for `kubectl logs`, `kubectl exec` and metrics-server:
   ```
   ❯ kubectl get csr --field-selector spec.signerName=kubernetes.io/kubelet-serving
   ```

The app `gitops/infrastructure/kubelet-csr-approver` approves the serving certificates
of the account B nodes. It also approves the new requests before a
certificate expires. It approves only node names and IPs in `10.1.1.0/24`.
If a request stays `Pending`, read it and approve it manually:
```
❯ kubectl get csr <csr-name> -o jsonpath='{.spec.request}' | base64 -d | openssl req -noout -text
❯ kubectl certificate approve <csr-name>
```

The nodes start in step 4, but they can only join after step 6. Until then,
the kubelet tries to connect again.

If `account_b_peering_status` is `INVALID`, make sure that account A is
subscribed to `us-chicago-1`. Then run this command in `terraform/accounts/a`:
```
❯ terraform apply -replace=oci_core_remote_peering_connection.account_b
```

If you upgrade the cluster version, replace the account B nodes one at a
time. Terraform ignores changes to the image and the user data, so you
must replace the nodes manually:
```
❯ kubectl drain --ignore-daemonsets --delete-emptydir-data <node-ip>
❯ kubectl delete node <node-ip>
❯ terraform apply -replace='oci_core_instance.node[0]'
```
Then do step 8 for the new node.

If the account B nodes hold replicas of `longhorn-account-b` volumes, do
these steps before you replace the next node:

1. Make sure that all volumes are `healthy`:
   ```
   ❯ kubectl -n longhorn get volumes.longhorn.io
   ```
2. Make sure that the new node has the tag `pool-b`:
   ```
   ❯ kubectl -n longhorn get nodes.longhorn.io <node-ip> -o jsonpath='{.spec.tags}'
   ```
3. Remove the Longhorn node of the old instance. Longhorn deletes it when
   scheduling is off:
   ```
   ❯ kubectl -n longhorn patch nodes.longhorn.io <old-node-ip> --type merge -p '{"spec":{"allowScheduling":false}}'
   ```

## Kubernets Access - kubeconfig
After running terraform in the [accounts/a](./examples/terraform/account-a) folder, a kubeconfig file
should be created in the terraform folder called `.kube.config`.
This can be used to access the cluster.
For a more regulated access, see the Teleport section below.

The terraform resources in the [clusters/oci](./examples/terraform/cluster) folder will rely on the kubeconfig.

## FluxCD
Most resources and core components of the k8s cluster are provisioned with fluxcd.
Flux syncs `gitops/clusters/oci` of the live repository. Copy
[examples/gitops/clusters/example](./examples/gitops/clusters/example) there. It adds the
`GitRepository` `platform` for this repository, and the `Kustomization` `platform` that
applies [gitops/platform](./gitops/platform) with these folders:

- [infrastructure](./gitops/infrastructure): ingress, certificates, DNS, secrets, storage, access, and Flux add-ons
- [monitoring](./gitops/monitoring): metrics, logs, dashboards, and cost exporters
- [tools](./gitops/tools): CI and other tools that run on the platform

Each app folder has a `flux.yaml` with its own Flux `Kustomization`.

Therefore we need a Github Personal acccess Token (`pat` - fine grained) in your repo.
```
# github permission scope for the token:
contents - read, write
commit statuses - read, write
webhooks - read, write
```

* Place this token in a private tfvars. This is used to
generate the fluxcd webhook url, which triggers fluxcd reconciliation after each
commit
* Place this token in the oci vault (`fluxcd-github-token`). This allows fluxcd
to annotate the github commit status, depending on the state of the `Kustomization`.

### Slack notifications
Two components post to Slack, and each one uses a different Slack credential.

Flux sends error events to a Slack channel through a Slack app. Error events
come from GitRepositories, Kustomizations, HelmReleases and HelmCharts. To set
it up, do these steps:

1. Create a Slack app at https://api.slack.com/apps ("From scratch").
2. In "OAuth & Permissions", add the bot scope `chat:write`.
3. Install the app in the workspace, and copy the "Bot User OAuth Token" (`xoxb-...`).
4. Put the token in the oci vault as `fluxcd-slack-webhook`.
5. In the Slack channel, type `/invite @<app name>`.
6. Put the channel ID in `flux_slack_channel_id` in [cluster-vars](./examples/gitops/clusters/example/cluster-vars.yaml).

To find the channel ID, open the channel details in Slack. The ID is at the
bottom of the "About" tab, for example `C0123456789`. If you skip step 5, Slack
refuses the messages with `not_in_channel`.

Alertmanager sends the Prometheus alerts to `#monitoring` through a Slack
incoming webhook (a URL that posts to one channel). Put the webhook URL in the
oci vault as `SLACK_API_URL`.

### PagerDuty notifications
Alertmanager also sends alerts with `severity=critical` to PagerDuty. These
alerts still go to Slack. To set it up, do these steps:

1. In PagerDuty, open the service, and add an "Events API V2" integration.
2. Copy the "Integration Key" (the routing key).
3. Put the key in the oci vault as `PAGERDUTY_ROUTING_KEY`.

If a Vault secret is missing, the `ExternalSecretNotReady` alert fires after
15 minutes. To make sure that Flux can post, read the logs of the
`notification-controller` in `flux-system`, and look for `failed to dispatch`.

### Fluxcd Operator
Migrating from the `flux bootstrap` method to the flux-operator might be tricky.
I lost most installed apps during my upgrade, because i misconfigured the
`FluxInstace.path` (this could've mitigated by setting `prune: false` on the KS).
Destroying the old Bootstrap resource during the TF apply, lead
to the removal of the fluxcd crds like `GitRepo, HelmRelease` etc
(had the remove the finalizers of the crds
to allow removal). This didn't impact my already deployed CRs though.
The Flux Operator takes care of reinstalling everything.

I've setup a Githup App and mostly followed the official guide,
this was pretty straightforward.

#### Development
Switching to a feature/dev branch is rather simple, just modify the
inCluster `FluxInstance` - search for the `sync` block and update the `ref`
section to the according branch.

## Teleport
[Teleport](https://goteleport.com/) is my preferred way to access the kuberentes api
### Prerequisites
In it's current state, teleport wants to setup a wildcard domain like `*.teleport.example.com` (could be disabled).
With OracleCloud managing the dns, this is not possible, as `cert-manager` is not
able to do a `dns01` challenge against orcale dns.
I've now switched to Cloudflare (also to mitigate costs of a few cents).

The Teleport <-> K8s Role (`k8s/system:masters`) is created by the teleport
operator (see the `fluxcd-addons/Kustomization`). The SSO setup is created with
[fluxcd](./gitops/infrastructure/teleport/rbac).

### ~Login via local User~ - removed
I've removed local users in teleport and am using SSO with github as idP.

This might still be useful for local setups not using SSO:

The login process must be `reset` for each user, so that
password and 2FA can be configured by each user in the WebUI.
The User can be created via the teleport-operator by creating a `TelepertUser` in
kubernetes.
```
# reset the user once
❯ k --kubeconfig ~/.kube/oci.kubeconfig exec -n teleport -ti deployment/teleport-cluster-auth -- tctl users reset nce

# login to teleport
❯ tsh login --proxy teleport.<cluster_domain>:443 --auth=local --user nce teleport.<cluster_domain>
```

### Login via Github
There's no user management in teleport, so no reset, or 2FA setup is needed.
```
❯ tsh login --proxy teleport.<cluster_domain>:443 --auth=github-acme --user nce teleport.<cluster_domain>

# login to the k8s cluster
❯ tsh kube login oci

# test
❯ k get po -n teleport
```

### Certificates
The x509 certs are managed by `cert-manager`. With the dns management done by
cloudflare, i've removed all `http01` challenges. The renewal process with
`http01` and cloudflare is [out of the box not possible][cert-manager-cloudflare]

Switching to `dns` challenge solves this issue.

### Known Issues
```
❯ tsh kube login oci
ERROR: connection error: desc = "transport: authentication handshake failed: tls: failed to verify certificate: x509: certificate signed by unknown authority"
```
When reinstalling teleport, during a logged in session, the tsh Client
throws this error. A logout & login has to happen.

## Gateway API - Loadbalancer setup
With the recent deprecation of the `nginx-ingress` project, i [switched][pr] to
[GatewayAPI][gatewayapi]. All `ingress` resources are replaced by `httproutes`.
I chose the [envoy-gateway][envoy-gateway] implementation, as they feature
`SecurityPolicies` which allow the protection of `httproutes` with OIDC auth.

With orcale providing a layer 7 loadbalancer, the oci-controller needs to
know which securitygroup should be associated with the lb. This is done by
annotating the Service. Using envoy, we have to add the annotations on an
`EnvoyProxy` CR. Unfortunately the value for the sg is created via terraform,
but is later needed on the object. In the past i used to write it in a configmap,
and helm was able to use the CM as value.yaml and annotated the resource.
This is now no longer possible, therefore the sg is currently hardcoded.

The Envoy service uses `externalTrafficPolicy: Local`. The load balancer
sends traffic only to its backend nodes that run an Envoy pod. If no backend
node runs an Envoy pod, all backends fail the health check. HTTPS connections
then get a reset during the TLS handshake. The `EnvoyProxy` CR prevents this:

* Envoy runs only on nodes without the label
  `node.kubernetes.io/exclude-from-external-load-balancers`. These nodes are
  the load balancer backends.
* Envoy has 2 replicas, which prefer different nodes. If one node is down, the
  other backend still serves traffic.

[pr]: https://github.com/nce/oci-free-cloud-k8s/pull/152
[gatewayapi]: https://gateway-api.sigs.k8s.io/
[envoy-gateway]: https://gateway.envoyproxy.io/

## Monitoring

# :money_with_wings: Cost
Overview of my monthly costs:
![](docs/cost.25.png)

# :books: Docs
A collection of relevant upstream documentation for reference

## Ingress
* LB Annotation [for oracle cloud][lb-annotations]
* Providing OCI-IDs to Helm Releases on [nginx][nginx-helm-lb-annotations]

## Cert Manager
* [DNS01 Challenge][cert-manager-dns-challenge]

## External Secrets
* [Advanced Templating for secrets][secrets-templating]

## External Dns
* [CRDs for DNS records][dns-crds]

## Teleport
* [teleport-operator][teleport-operator]
* Teleport [User/Roles RBAC][teleport-rbac]
* Mapping to teleport role
* [SSO with GithubConnector][teleport-github-sso] and [External Client Secret][teleport-client-secret]
* [Helm Chart Deploy Infos][teleport-helm-doc] & [Helm Chart ref][teleport-helm-chart]

## FluxCD
* [Monitoring setup][flux-monitoring]
* [Webhook Config][flux-webhook]
* [Webhook Url Hashing][flux-webhook-hashing]
* [FluxCD Operator][flux-operator-migration]
* [Slack Provider][flux-slack-provider]

[lb-annotations]: https://github.com/oracle/oci-cloud-controller-manager/blob/master/docs/load-balancer-annotations.md
[nginx-helm-lb-annotations]: https://github.com/kubernetes/ingress-nginx/blob/74ce7b057e8d4ac96d2e11e027930397e5f70010/charts/ingress-nginx/templates/controller-service.yaml#L7
[cert-manager-dns-challenge]: https://cert-manager.io/docs/configuration/acme/dns01/
[cert-manager-cloudflare]: https://ryanschiang.com/cloudflare-letsencrypt-http-01

[secrets-templating]: https://external-secrets.io/v0.15.0/guides/templating/#helm

[dns-crds]: https://kubernetes-sigs.github.io/external-dns/latest/docs/sources/crd/#using-crd-source-to-manage-dns-records-in-different-dns-providers

[teleport-client-secret]: https://goteleport.com/docs/admin-guides/infrastructure-as-code/teleport-operator/secret-lookup/#step-23-create-a-custom-resource-referencing-the-secret
[teleport-github-sso]: https://goteleport.com/docs/admin-guides/access-controls/sso/github-sso/
[teleport-rbac]: https://goteleport.com/docs/admin-guides/access-controls/getting-started/#step-13-add-local-users-with-preset-roles
[teleport-helm-chart]: https://goteleport.com/docs/reference/helm-reference/teleport-cluster/
[teleport-helm-doc]: https://goteleport.com/docs/admin-guides/deploy-a-cluster/helm-deployments/kubernetes-cluster/
[teleport-operator]: https://goteleport.com/docs/admin-guides/infrastructure-as-code/teleport-operator/

[flux-monitoring]: https://fluxcd.io/flux/monitoring/metrics/#monitoring-setup
[flux-webhook]: https://fluxcd.io/flux/guides/webhook-receivers/
[flux-webhook-hashing]: https://github.com/fluxcd/notification-controller/issues/1067
[flux-operator-migration]: https://fluxcd.control-plane.io/operator/flux-bootstrap-migration/
[flux-slack-provider]: https://fluxcd.io/flux/components/notification/providers/#slack

# Upgrading the Kubernetes Version
## Automatic Upgrading
Upgrading the nodepool and the controlplane is done by running terraform in the
accounts/a folder now. It'll suggest the highest possible k8s version and start the
controlplane update.
After the successful update we run [cycleNode.sh](./terraform/modules/account-a/cycleNodes.sh) to
remove one worker, add a new one, wait for longhorn volume sync, and remove the next.

## Manual Upgrading
I recommend only upgrading to the version the first command (`available-kubernetes-upgrades`) shows.
Other upgrades, or jumps to the latest version not being shown, might break the process.
The [K8s Skew policy][k8s-skew] allows the worker nodes (`kubelets`)
to be three minor versions behind, so you might be alright, if you incrementally update the controlplane,
before updating the nodepool.

[k8s-skew]: https://kubernetes.io/releases/version-skew-policy/#kubelet

The commands should be executed inside `terraform/accounts/a` of the live repository
```
# get new cluster versions
❯ oci ce cluster get --cluster-id $(terraform output --raw k8s_cluster_id) | jq -r '.data."available-kubernetes-upgrades"'

# update the cluster version with the information from above
❯ sed -i '' 's/default = "'$(terraform output --raw kubernetes_version)'"/default = "v1.31.1"/' _variables.tf

# upgrade the controlplane and the nodepool & images
# this shouldn't roll the nodes and might take around 10mins
❯ terraform apply
```
If the apply fails with `open ../../.kube.config: permission denied`, Terraform must write a new kubeconfig.
The file is read-only (`file_permission = 0400`). Run `chmod 600 ../../.kube.config`, then run `terraform apply` again.
 To roll the nodes, i cordon & drain the k8s node:
```
❯ k drain <k8s-node-name> --force --ignore-daemonsets --delete-emptydir-data
❯ k cordon <k8s-node-name>
```
A node deletion in k8s doesn't trigger a change in the `nodepool`. For that, we
need to terminate the correct instance. But i haven't figured out how to delete the -
currently cordoned - node, only using `oci`.

So, login to the webui -> Oke Cluster -> Node pool and check for the right
instance by looking at the private_ip and copy the id.

Now terminate that instance:
```
❯ oci compute instance terminate --force --instance-id <oidc.id>
```
This triggers a node recreation. Now wait till the node is Ready; And then wait for
longhorn to sync the volumes.
```
# wait until all volumes are healthy again
❯ k get -w volumes.longhorn.io -A
```
Repeat the cordon/drain/terminate for the second node.
### OKE Upgrade 1.31.1
For the current update, i've written above upgrade instructions.
Worked flawlessly, though still with a bit of manual interaction in the webui...

### OKE Upgrade 1.29.1
I mostly skipped `1.27.2` & `1.28.2` (on the workers) and went for the `1.29` release. As the UI didn't
prompt for a direct upgrade path of the control-plane, i upgraded the k8s-tf
version to the prompted next release, ran the upgrade, and continued with the next version.

The worker nodes remained at `1.26.7` during the oke upgrade, which worked because with 1.28
the new skew policy allows for worker nodes to be three versions behind.

### OKE Upgrade 1.25.4

:warning: remember to remove any `PSP`s first

1. Upgrade the nodepool & cluster version by setting the k8s variable; Run terrafrom (takes ~10min)
2. Drain/Cordon worker01
3. Go to the UI; delete the worker01 from the nodepool
4. Scale the Nodepool back to 2 (takes ~10min)
5. Wait for longhorn to sync (no volume in state `degraded`)
6. repeat for second node (2-5)

### OKE Upgrade 1.24

The 1.23.4 -> 1.24.1 Kubernetes Upgrade went pretty smooth, but by hand.

I followed the official guide:

- https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengupgradingk8smasternode.htm
- https://docs.oracle.com/en-us/iaas/Content/ContEng/Tasks/contengupgradingk8sworkernode.htm

Longhorn synced all volumes after the new node got ready. No downtime experienced.
