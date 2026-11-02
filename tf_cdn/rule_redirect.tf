# HTTPS enforcement: HSTS plus HTTP → HTTPS redirect (Property Manager)
#
# HSTS (HTTP Strict Transport Security) is the PREFERRED way to keep clients on HTTPS: once a browser
# has seen the Strict-Transport-Security header, it upgrades every later request to HTTPS itself,
# before anything is sent over plain HTTP.
#
# The redirect is a FAILSAFE for requests HSTS can't cover: a client's first visit, expired HSTS entries,
# and clients that ignore HSTS (including anyone deliberately using HTTP). It's the HSTS behavior's
# built-in option (redirect = true, 301 by default), not a separate rule. It's what ensures content is
# never served over plain HTTP, so keep redirect = true unless something else blocks HTTP.
#
# Enabled for every property by default (var.rule_redirect defaults to {}).
# TODO: Setting rule_redirect = null does not currently disable this rule; it fails with "Attempt to get
# attribute from null value". Options: count on this data source (null = off), or nullable = false (always on).

data "akamai_property_rules_builder" "rule_redirect" {
  rules_v2024_08_13 {
    name = "HSTS and HTTPS redirect"
    behavior {
      http_strict_transport_security {
        enable               = var.rule_redirect.enable              # HSTS header (preferred)
        include_sub_domains  = var.rule_redirect.include_sub_domains # off by default; can break subdomains without valid HTTPS
        max_age              = var.rule_redirect.max_age
        preload              = var.rule_redirect.preload  # off by default; requires registering the domain at hstspreload.org
        redirect             = var.rule_redirect.redirect # HTTP -> HTTPS redirect (failsafe). false = HTTP content is served!
        redirect_status_code = var.rule_redirect.redirect_status_code
      }
    }
  }
}
