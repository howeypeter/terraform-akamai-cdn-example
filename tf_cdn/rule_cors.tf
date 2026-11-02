# CORS (cross-origin resource sharing) headers (Property Manager)
#
# Adds CORS response headers so browsers allow other sites to call this property. Defaults are EXAMPLES:
# any origin, GET and POST, no credentials, 86400s preflight cache. Set your own in the module call.
#
# Security: allow_credentials = true lets browsers send cookies or client certificates. The rule_cors
# validation requires allowed_origins (specific sites) whenever credentials are allowed, because credentials
# from ANY origin would let any website make logged-in requests.
#
# CORS preflight requests use the OPTIONS method, which must be allowed. In this module, allow_options is
# currently enabled in rule_baseline.tf, so use this rule together with rule_baseline, or allow OPTIONS
# another way. (TODO: consider moving allow_options into this rule.)
#
# Choosing allowed_origins: the authoritative source is your applications' code and configuration. Inventory
# every site that calls this property (front ends, partners, embedded widgets).
# As a SECONDARY cross-check only, rule_baseline logs the request Origin header (PMUSER_HEADER_ORIGIN) in the
# DataStream custom log field. Do this BEFORE restricting origins, and let it run for weeks or more to catch
# infrequent callers. Once origins are restricted, browsers block disallowed sites: often only a preflight
# (OPTIONS) request, or a response the page can't use, reaches the logs, and those pages fail to load the content.

data "akamai_property_rules_builder" "rule_cors" {
  rules_v2024_08_13 {
    name                  = "CORS headers"
    comments              = "Custom policy to manage custom CORS headers"
    criteria_must_satisfy = "all"
    behavior {
      cors_support {
        allow_credentials = try(var.rule_cors.allow_credentials, false)
        allow_headers     = "ANY"
        allow_origins     = try(length(var.rule_cors.allowed_origins) > 0, false) ? "SPECIFIED" : "ANY"
        enabled           = true
        expose_headers    = try(var.rule_cors.expose_headers, [])
        methods           = try(var.rule_cors.methods, ["GET", "POST", ])
        origins           = try(var.rule_cors.allowed_origins, null)
        preflight_max_age = try(var.rule_cors.preflight_max_age, "86400s")
      }
    }
    dynamic "criterion" {
      for_each = try(var.rule_cors.criterion.hostname, null) != null ? [var.rule_cors.criterion] : []
      content {
        hostname {
          match_operator = try(criterion.value.hostname.match_operator, "IS_ONE_OF")
          values         = try(criterion.value.hostname.values, null)
        }
      }
    }
  }
}
