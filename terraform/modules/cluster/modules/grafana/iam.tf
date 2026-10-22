# The CostReports policy below uses this group for oci-cost-collector.
resource "oci_identity_dynamic_group" "grafana_instances" {
  #Required
  compartment_id = var.compartment_id
  description    = "Grafana Monitoring"
  name           = "grafana"

  # all instances
  matching_rule = "All {instance.id = '*'}"
}

# https://docs.oracle.com/en-us/iaas/Content/Billing/Tasks/accessingusagereports.htm
# The cost reports are in a bucket of an Oracle tenancy. The OCID below is the
# same for all customers. oci-cost-collector reads the reports with this policy.
resource "oci_identity_policy" "cost_reports" {
  compartment_id = var.tenancy_id
  description    = "allow oci-cost-collector to read the cost reports"
  name           = "CostReports"
  statements = [
    "define tenancy usage-report as ocid1.tenancy.oc1..aaaaaaaaned4fkpkisbwjlr56u7cj63lf3wffbilvqknstgtvzub7vhqkggq",
    "endorse dynamic-group 'Default'/'grafana' to read objects in tenancy usage-report"
  ]
}
