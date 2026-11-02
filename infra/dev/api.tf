module "api" {
  source = "../../tf_cdn"

  property_name   = "mycompany-api-${local.env}"
  origin_hostname = "origin-api.dev.example.com"
  origin_valid_certs = [
    "{{Origin Hostname}}",
    "{{Forward Host Header}}",
    "*.example.com", # also accept the origin's wildcard certificate
  ]
  environment  = local.env
  default_uuid = "default"

  edge_hostnames = {
    "api.dev.example.com"          = local.cert_hostname
    "accounts-api.dev.example.com" = local.cert_hostname
  }

  rule_akamai_ps_advanced = {
    rule_uuid     = "aaaaaaaa-aaaa-aaaa-aaaa-000000000005"
    name          = "Akamai PS advanced: uncompressible status codes"
    behavior_uuid = "bbbbbbbb-bbbb-bbbb-bbbb-000000000005"
    description   = "Status codes Akamai should not compress"
    custom_xml    = "<edgeservices:lma.uncompressable-status-codes>200 201 401 404 409 500 504</edgeservices:lma.uncompressable-status-codes>"
  }

  rule_redirect = {}
  rule_baseline = {}
  rule_cors = {
    preflight_max_age = "600s"
  }
}
