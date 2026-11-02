module "www" {
  source = "../../tf_cdn"

  property_name   = "mycompany-www-${local.env}"
  environment     = local.env
  origin_hostname = "origin-www.dev.example.com"
  default_uuid    = "default"

  contact_email = ["web-team@example.com"] # overrides the module default (ops@example.com)

  edge_hostnames = {
    "www.dev.example.com"    = local.cert_hostname
    "static.dev.example.net" = "dev.example.net.edgekey.net" # a hostname can use a different edge hostname/certificate
  }

  rule_akamai_ps_advanced = {
    rule_uuid     = "aaaaaaaa-aaaa-aaaa-aaaa-000000000001"
    name          = "Akamai PS advanced: 16 KB response headers"
    behavior_uuid = "bbbbbbbb-bbbb-bbbb-bbbb-000000000001"
    description   = "Allow response headers up to 16 KB"
    custom_xml    = "<network:http.response-headers.max-size>16384</network:http.response-headers.max-size>"
  }
  # rule_akamai_ps_custom_behavior = {} # Enable after replacing the placeholder custom behavior ID in tf_cdn.

  rule_nonprod_acl = {
    # Optional: allow IPs from the prod-managed Client List (uncomment the lookups at the bottom first).
    # allowed_ips = data.akamai_clientlist_list.office.list.items[*].value
  }
  rule_redirect = {}
  rule_baseline = {
    enable_grn = true # adds the Akamai-GRN request ID response header
  }
  rule_gzip = {}
}

# OPTIONAL (commented out, untested): reuse a Client List as this property's ACL allow list.
# The Client List itself is DEFINED IN PROD: infra/prod/client_lists.tf creates and activates it.
# Client Lists are account-level, so dev can read one by name. Apply infra/prod first so the list exists.
# Note: property rules can't reference a Client List directly (client_ip takes literal IPs), so the
# lookup reads the list's IPs and passes them to the ACL as allowed_ips.
#
# data "akamai_clientlist_lists" "office" {
#   name = "mycompany_public_cidrs_ipv4" # must match the list name in infra/prod/client_lists.tf
#   type = ["IP"]
# }
#
# data "akamai_clientlist_list" "office" {
#   list_id = one(data.akamai_clientlist_lists.office.list_ids)
# }
