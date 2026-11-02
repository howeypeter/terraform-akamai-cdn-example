module "www" {
  source = "../../tf_cdn"

  property_name   = "mycompany-www-${local.env}"
  group_name      = var.group_name # explicit form: from terraform.tfvars (dev relies on the module default)
  environment     = local.env
  origin_hostname = "origin-www.example.com"
  default_uuid    = "default"

  prod_activation_version = 1 # Example: prod is pinned. Bump to the version you've reviewed and want live.

  edge_hostnames = {
    "www.example.com"    = local.cert_hostname
    "static.example.com" = local.cert_hostname
  }

  rule_akamai_ps_advanced = {
    rule_uuid     = "aaaaaaaa-aaaa-aaaa-aaaa-000000000004"
    name          = "Akamai PS advanced: 16 KB response headers"
    behavior_uuid = "bbbbbbbb-bbbb-bbbb-bbbb-000000000004"
    description   = "Allow response headers up to 16 KB"
    custom_xml    = "<network:http.response-headers.max-size>16384</network:http.response-headers.max-size>"
  }

  rule_redirect = {}
  rule_baseline = {
    enable_datastream = true # opt-in: send this property's logs to datastream-prod (see datastream.tf)
    mpulse_exclude_paths = [
      "/checkout/*",
      "/account/*",
    ]
    mpulse_api_key = "XXXXX-XXXXX-XXXXX-XXXXX-00003" # Placeholder: replace with your mPulse API key.
  }
  rule_gzip = {}
}
