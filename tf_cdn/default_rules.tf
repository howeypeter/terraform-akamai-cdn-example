# Default rule (Property Manager top-level rule)
#
# Every property starts here: origin settings, CP code, and downstream caching, then the child rules below.
# Rules are evaluated top to bottom and the LAST matching rule wins, so order matters:
#   - The PS rules (custom behavior, advanced) come first.
#   - Then redirect, baseline, gzip, CORS, and any custom_rules passed in by the caller.
#   - rule_nonprod_acl is LAST, so the ACL decision overrides everything above it.
# Each child rule is included only when its module input is not null.

data "akamai_property_rules_builder" "default" {
  rules_v2024_08_13 {

    name      = "default"
    uuid      = var.default_uuid
    is_secure = true
    comments  = "Rules are evaluated from top to bottom and the last matching rule wins."
    # Origin Behavior: https://techdocs.akamai.com/terraform/reference/ga-origin
    behavior {
      origin {
        hostname               = var.origin_hostname
        origin_type            = "CUSTOMER"
        forward_host_header    = "REQUEST_HOST_HEADER"
        cache_key_hostname     = "REQUEST_HOST_HEADER"
        compress               = var.origin_supports_gzip
        enable_true_client_ip  = true
        http_port              = 80
        https_port             = 443
        ports                  = ""
        custom_valid_cn_values = var.origin_valid_certs
        ip_version             = "IPV4"
        origin_certs_to_honor  = "STANDARD_CERTIFICATE_AUTHORITIES"
        origin_sni             = false
        origin_certificate     = ""
        # Which certificate authorities to trust for the origin's TLS certificate. THIRD_PARTY_AMAZON fits AWS
        # origins (e.g. ALB/ACM certificates). Adjust for your origin.
        standard_certificate_authorities = [
          "akamai-permissive",
          "THIRD_PARTY_AMAZON",
        ]
        min_tls_version   = "DYNAMIC"
        tls_version_title = ""
        verification_mode = "CUSTOM"

        true_client_ip_client_setting = false
        true_client_ip_header         = "True-Client-IP"
      }
    }

    behavior {
      cp_code {
        value {
          id   = akamai_cp_code.this.id
          name = akamai_cp_code.this.name
        }
      }
    }
    behavior {
      downstream_cache {
        behavior = "TUNNEL_ORIGIN"
      }
    }
    children = concat(
      var.rule_akamai_ps_custom_behavior != null ? [data.akamai_property_rules_builder.rule_akamai_ps_custom_behavior.json] : [],
      var.rule_akamai_ps_advanced != null ? [data.akamai_property_rules_builder.rule_akamai_ps_advanced.json] : [],
      var.rule_redirect != null ? [data.akamai_property_rules_builder.rule_redirect.json] : [],
      var.rule_baseline != null ? [data.akamai_property_rules_builder.rule_baseline.json] : [],
      var.rule_gzip != null ? [data.akamai_property_rules_builder.rule_gzip.json] : [],
      var.rule_cors != null ? [data.akamai_property_rules_builder.rule_cors.json] : [],
      var.custom_rules,
      var.rule_nonprod_acl != null ? [data.akamai_property_rules_builder.rule_nonprod_acl.json] : [],
    )
    variable {
      name        = "PMUSER_PROPERTY"
      description = "Name of the CDN property, logged in the DataStream custom log field (see rule_baseline)"
      value       = var.property_name
      hidden      = true
      sensitive   = false
    }
    variable {
      name        = "PMUSER_HEADER_ORIGIN"
      description = "Client request Origin header, set and logged by rule_baseline (useful when reviewing CORS)"
      value       = ""
      hidden      = false
      sensitive   = false
    }
  }
}
