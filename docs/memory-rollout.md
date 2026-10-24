# Memory reservation rollout

Adopt these changes in separate module releases, in this order. Each row is a
release gate; do not combine the application or Teleport stages. The PRs are
stacked for review, but merging a PR is not approval to adopt its release.

| Stage | Workloads |
| --- | --- |
| 1 | Prometheus and its reloaders, Alloy main container, Flux reservations and chart pins |
| 2 | Lightweight controllers, exporters and Alloy reloader |
| 3a | Envoy controller and data plane |
| 3b | Grafana, its sidecars and dashboard download init container |
| 3c | Jenkins reload sidecar and reload init container |
| 3d | Loki rules sidecar |
| 3e | OCI-cost database and bootstrap init container |
| 3f | Alertmanager and its reloaders |
| 4 | Longhorn control plane and CSI components |
| Final 1 | Teleport operator |
| Final 2 | Teleport proxy and wait init container |
| Final 3 | Teleport auth |

Before each adoption, recalculate node capacity from current pod requests and
placement, including the maximum init-container requirement, rollout surge,
usage above requests and unreserved storage memory. Reservations are not a cap
on actual memory use. Keep Prometheus placement unchanged in these PRs.

Keep all six module references in the live repository aligned to the same
release. Adopt one stage, verify readiness, OOM terminations, restarts, node
pressure and representative service activity, then observe for at least 24
hours before advancing. Review a complete seven-day cycle before treating the
targets as established. Stop on a regression; revert the adoption commit to the
previous release and verify recovery before resuming.

CPU requests and limits, replicas, workload versions, placement and storage
configuration stay unchanged. Keep Jenkins main and init resources, Loki's
512Mi main request, both Vigil 256Mi requests, provider-managed add-ons,
Longhorn engine-image pods and instance-manager memory exceptions. Preserve
Longhorn replication and instance-manager CPU guarantees. Before stage 4,
confirm healthy volumes and backups, no active rebuild, and enough headroom
for the CSI and manager rollouts.

Prometheus and Alertmanager reloader overrides belong to their own CRs; a
global reloader setting would couple their rollouts. Flux chart versions are
pinned to the versions deployed when this series was prepared. Validate the
resolved Flux distribution version again before adoption.

Teleport runs last. Verify a separate recovery access path before maintenance.
After each component change, perform a fresh login and an explicit-context
Kubernetes read, and observe normal sessions before proceeding. Stop and roll
back on any access regression.

For every stage, render the pinned charts before and after, apply Helm
post-render patches, inspect operator CR overrides and effective init/regular
container requests, and compare CPU, images, replicas, storage and placement.
Run Kustomize with Flux substitution, kubeconform, Terraform formatting and
validation after initialization without a backend, and the secret scan. All
required PR checks must pass before release review. No application API or data
schema migration is involved.
