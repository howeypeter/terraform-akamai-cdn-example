# Akamai Professional Services (PS) custom behavior
#
# Custom behaviors are a real, sparsely documented Akamai feature, so this is a short, clearly labeled example.
#
# A custom behavior is a block of Akamai metadata (XML) that Akamai Professional Services writes for your
# account. It does something Property Manager doesn't offer as a standard behavior (for example, allowing
# larger response headers, such as 16 KB). You can't see or edit the XML yourself; Akamai gives you an ID
# (cbe_<number>) and you reference it from a rule.
#
# How to use it:
#   1. Akamai PS creates the custom behavior in your account and gives you its ID.
#   2. Replace the placeholder behavior_id below with that ID (hard-coded on purpose: it's tied to your account).
#   3. Enable the rule in a module call: rule_akamai_ps_custom_behavior = {}.
#   4. If PS added it to an existing property in Control Center first, bring it into Terraform by adding the same
#      behavior_id here, plus rule_uuid / behavior_uuid in the module call if the deployed rule has them,
#      so the next plan matches what's already deployed.
#
# The placeholder ID doesn't exist in any account, so enabling this rule without replacing it fails safely on apply.

data "akamai_property_rules_builder" "rule_akamai_ps_custom_behavior" {
  rules_v2024_08_13 {
    name                  = try(var.rule_akamai_ps_custom_behavior.name, "Akamai PS custom behavior")
    comments              = "Akamai Professional Services custom behavior (account-specific)."
    criteria_must_satisfy = "all"
    # Optional UUIDs: Akamai PS sometimes deploys these with fixed UUIDs and sometimes without. Set only the ones
    # present in the deployed rule tree; leave them out otherwise (they're then omitted, not sent empty).
    uuid = try(var.rule_akamai_ps_custom_behavior.rule_uuid, null) # the rule's UUID, if any
    behavior {
      custom_behavior {
        behavior_id = "cbe_000000000"                                             # PLACEHOLDER: replace with the custom behavior ID from Akamai PS.
        uuid        = try(var.rule_akamai_ps_custom_behavior.behavior_uuid, null) # the custom behavior's UUID, if any
      }
    }
  }
}
