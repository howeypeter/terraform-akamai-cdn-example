# Nonprod ACL rule (Property Manager)
#
# This adds a SECONDARY, property-level IP allow list inside the Property Manager rule tree:
# default deny, then allow the listed IPs. It's meant for simple cases such as restricting
# nonprod properties to company and Akamai support IPs.
#
# PRIMARY IP access control should live in Akamai's WAF, App & API Protector (formerly Kona
# Site Defender), using its IP/Geo Firewall with Client Lists (or legacy Network Lists). In
# Terraform, that's the akamai_appsec_* resources (e.g. akamai_appsec_ip_geo) together with
# akamai_clientlist_* (or akamai_networklist_*) resources.
# Use this rule as a backstop, or where a security configuration isn't available.

locals {
  # Allow Akamai engineers access to test (e.g. Akamai support / Secure Staging Network IPs).
  # PLACEHOLDERS: these are RFC 5737 documentation addresses that never route on the internet,
  # so they match no real client. Replace them with Akamai's current published support IP ranges.
  # TODO: Replace this hard-coded list with a data lookup. The Akamai Terraform provider has no data
  # source for Akamai's own support/staging IP ranges (as of provider v11). Options: keep these IP ranges in an
  # Akamai Network List / Client List or an AWS prefix list and look that up, or use a provider data
  # source if one is added.
  akamai_support_cidrs = [
    "192.0.2.0/28",     # akamai-support-range: placeholder (RFC 5737). Replace with an Akamai support range.
    "198.51.100.10/32", # akamai-support-ip: placeholder (RFC 5737). Replace with an Akamai support IP.
  ]
}

data "akamai_property_rules_builder" "rule_nonprod_acl" {
  rules_v2024_08_13 {
    name                  = "ACL"
    comments              = "ACL rule - nested. Default deny. Child rules MUST use the same reason_id string."
    criteria_must_satisfy = "all"
    behavior {
      deny_access {
        enabled = true
        reason  = var.acl_identifier
      }
    }
    children = concat(
      [data.akamai_property_rules_builder.acl_allow_mycompany_vpn_egress.json],
      [data.akamai_property_rules_builder.acl_allow_akamai_support_ips.json],
      try(var.rule_nonprod_acl.custom_acl, []),
    )
  }
}

data "akamai_property_rules_builder" "acl_allow_mycompany_vpn_egress" {
  rules_v2024_08_13 {
    name                  = "allow-mycompany-vpn-egress"
    comments              = "ACL allowing company VPN egress / testing tool IPs, plus allowed_ips from the caller"
    criteria_must_satisfy = "all"
    criterion {
      client_ip {
        match_operator = "IS_ONE_OF"
        use_headers    = false
        values = sort(concat(
          try(var.rule_nonprod_acl.allowed_ips, []),
          [
            "203.0.113.0/28",   # my-corp-vpn-ip: placeholder (RFC 5737). Replace with your VPN egress range.
            "203.0.113.100/32", # my-testing-tool-ip: placeholder (RFC 5737). Replace with a testing tool's IP.
          ],
          # Optional: uncomment along with the prefix list lookup in main.tf.
          # tolist(data.aws_ec2_managed_prefix_list.mycompany_vpn_egress_ipv4.entries.*.cidr),
        ))
      }
    }
    behavior {
      deny_access {
        enabled = false
        reason  = var.acl_identifier
      }
    }
  }
}

data "akamai_property_rules_builder" "acl_allow_akamai_support_ips" {
  rules_v2024_08_13 {
    name                  = "allow-akamai-support-ips"
    comments              = "ACL allowing Akamai support IPs (and, optionally, company public CIDRs)"
    criteria_must_satisfy = "all"
    criterion {
      client_ip {
        match_operator = "IS_ONE_OF"
        use_headers    = false
        values = sort(concat(
          # Optional: uncomment along with the prefix list lookup in main.tf.
          # tolist(data.aws_ec2_managed_prefix_list.mycompany_public_cidrs_ipv4.entries.*.cidr),
          local.akamai_support_cidrs,
        ))
      }
    }
    behavior {
      deny_access {
        enabled = false
        reason  = var.acl_identifier
      }
    }
  }
}
