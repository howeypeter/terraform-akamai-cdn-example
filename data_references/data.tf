locals {
  product_id = "prd_Fresca" # Akamai internal codename for ION Property Manager Standard
}

data "akamai_contracts" "this" {}

data "akamai_contract" "this" {
  group_name = var.group_name
}

data "akamai_groups" "this" {}

data "akamai_group" "this" {
  group_name  = var.group_name
  contract_id = data.akamai_contract.this.id
}

data "akamai_properties" "this" {
  contract_id = data.akamai_contract.this.id
  group_id    = data.akamai_group.this.id
}

data "akamai_property_includes" "this" {
  contract_id = data.akamai_contract.this.id
  group_id    = data.akamai_group.this.id
}

# Reference: look up CP codes in the group. Not used by the current lookups;
# uncomment (along with the cp_codes output in outputs.tf) when you need CP code IDs.
# data "akamai_cp_codes" "this" {
#   contract_id = data.akamai_contract.this.id
#   group_id    = data.akamai_group.this.id
#   # Optional filters:
#   # filter_by_name       = "my-cp-code"
#   # filter_by_product_id = "prd_Fresca"
# }

data "akamai_property_hostnames" "this" {
  for_each    = toset(data.akamai_properties.this.properties.*.property_id)
  contract_id = data.akamai_contract.this.id
  group_id    = data.akamai_group.this.id
  property_id = each.key
}

data "akamai_datastreams" "this" {
  group_id = split("_", data.akamai_group.this.id)[1]
}

data "akamai_networklist_network_lists" "this" {}
