# Akamai Professional Services (PS) advanced behavior (inline metadata XML)
#
# Like custom behaviors, advanced behaviors are a real, sparsely documented Akamai feature, so this is a short,
# clearly labeled example. See also rule_akamai_ps_custom_behavior.tf (Akamai-provided config referenced by ID).
#
# An advanced behavior holds raw Akamai metadata XML that only Akamai (Professional Services or your account
# team) can write or change. It enables settings Property Manager doesn't expose as standard behaviors, for example:
#   <network:http.response-headers.max-size>16384</network:http.response-headers.max-size>    (16 KB response headers)
#   <edgeservices:lma.uncompressable-status-codes>200 201 404</edgeservices:lma.uncompressable-status-codes>
#
# Because you can't author or edit it, Terraform must send it back EXACTLY as Akamai deployed it:
#   1. Akamai adds the advanced behavior to your property in Control Center.
#   2. Copy its XML and any UUIDs from the property's rule tree (e.g. after `terraform import`, or the
#      Property Manager API): the rule's uuid (rule_uuid) and/or the advanced behavior's uuid (behavior_uuid).
#   3. Pass them in the module call: rule_akamai_ps_advanced = { custom_xml = "...", rule_uuid = "...", behavior_uuid = "..." }.
#      Akamai PS sometimes deploys these with UUIDs and sometimes without: set only the UUIDs present in the
#      deployed rule tree and leave the others out (they're then omitted, not sent empty).
# If the XML or UUIDs don't match what Akamai deployed, the property update is rejected.

data "akamai_property_rules_builder" "rule_akamai_ps_advanced" {
  rules_v2024_08_13 {
    name                  = try(var.rule_akamai_ps_advanced.name, "Akamai PS advanced behavior")
    comments              = "Akamai Professional Services advanced behavior (inline XML; must match what Akamai deployed)."
    criteria_must_satisfy = "all"
    uuid                  = try(var.rule_akamai_ps_advanced.rule_uuid, null) # the rule's UUID, as deployed by Akamai
    behavior {
      advanced {
        description = try(var.rule_akamai_ps_advanced.description, "")
        xml         = try(var.rule_akamai_ps_advanced.custom_xml, null)
        uuid        = try(var.rule_akamai_ps_advanced.behavior_uuid, null) # the advanced behavior's UUID, as deployed by Akamai
      }
    }
  }
}
