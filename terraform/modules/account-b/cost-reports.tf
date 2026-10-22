# The HelmRelease oci-cost-collector-account-b (gitops/monitoring/oci-cost/helm.yaml) runs
# on the account B nodes and reads the cost reports of account B with their
# instance principal.
resource "oci_identity_dynamic_group" "cost_reports" {
  compartment_id = var.tenancy_id
  name           = "cost-reports"
  description    = "k8s-b nodes that read the cost reports"
  matching_rule  = "All {instance.compartment.id = '${var.compartment_id}'}"
}

# https://docs.oracle.com/en-us/iaas/Content/Billing/Tasks/accessingusagereports.htm
# The cost reports are in a bucket of an Oracle tenancy. The OCID below is the
# same for all customers.
resource "oci_identity_policy" "cost_reports" {
  compartment_id = var.tenancy_id
  name           = "CostReports"
  description    = "allow oci-cost-collector-b to read the cost reports"
  statements = [
    "define tenancy usage-report as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq",
    "endorse dynamic-group 'Default'/'${oci_identity_dynamic_group.cost_reports.name}' to read objects in tenancy usage-report",
  ]
}

# The tenancy OCID is not in git, so the oci-cost flux/kustomization substitutes
# ${oci_tenancy_id_b} in the HelmRelease from this ConfigMap. The name is from
# oci-billing-exporter, which oci-cost-collector replaced.
resource "kubernetes_config_map_v1" "oci_billing_exporter_b_vars" {
  metadata {
    name      = "oci-billing-exporter-b-vars"
    namespace = "flux-system"
  }

  data = {
    oci_tenancy_id_b = var.tenancy_id
  }
}
