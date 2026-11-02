# PLACEHOLDER output. This module doesn't export any real values yet.
#
# To use this module's settings elsewhere (for example in other infra/ modules, DataStream config, or CI/CD),
# replace or add outputs here, e.g.:
#   output "property_id"    { value = akamai_property.this.id }
#   output "latest_version" { value = akamai_property.this.latest_version }
#   output "cp_code_id"     { value = akamai_cp_code.this.id }
#   output "acl_identifier" { value = var.acl_identifier } # lets infra/ ACL rules reuse the same reason ID
# Callers then read them as module.<name>.<output>.
output "data_output" {
  description = "Placeholder output; see the comments in output.tf for examples."
  value       = "debug"
}

