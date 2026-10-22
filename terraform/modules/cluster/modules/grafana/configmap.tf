# oci-cost-collector reads the cost reports from the bucket named after the
# tenancy OCID. The OCID is not in git, so the oci-cost flux/kustomization
# (gitops/monitoring/oci-cost) substitutes ${oci_tenancy_id} in the HelmRelease
# from this ConfigMap. The name is from oci-billing-exporter, which it replaced.
resource "kubectl_manifest" "oci_billing_exporter_vars" {
  yaml_body = <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: oci-billing-exporter-vars
  namespace: flux-system
data:
  oci_tenancy_id: ${var.tenancy_id}
YAML
}
