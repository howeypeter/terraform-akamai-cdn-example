# Akamai Client Lists (managed here, shared across environments)
#
# Client Lists are ACCOUNT-level: they aren't tied to an environment. This file is the single place they're
# created and kept in sync, then activated on both Akamai networks (STAGING and PRODUCTION).
# Other folders can read them; e.g. infra/dev/www.tf has a commented-out lookup that uses
# mycompany_public_cidrs_ipv4 as its ACL allow list. Apply infra/prod first so the lists exist.
#
# Two ways to fill a list are shown:
#   - from an AWS managed prefix list (source of truth kept in AWS), and
#   - from a hard-coded list in Terraform.

# Contract and group IDs for the lists come from the lookups in datastream.tf (data.akamai_contract.this /
# data.akamai_group.this, from var.group_name). Client Lists want them WITHOUT Akamai's prefixes ("ctr_", "grp_").
# NOTE: this conversion is untested against a live account; check it on your first plan.
locals {
  clientlist_contract_id = trimprefix(data.akamai_contract.this.id, "ctr_")
  clientlist_group_id    = tonumber(split("_", data.akamai_group.this.id)[1])

  # PLACEHOLDERS (RFC 5737 documentation ranges): replace with your partner's real IP ranges.
  partner_ipv4 = [
    "192.0.2.0/28",    # partner-office: placeholder
    "198.51.100.0/28", # partner-datacenter: placeholder
  ]
}

# AWS managed prefix lists used as sources (PLACEHOLDER names: replace with your own prefix lists).
data "aws_ec2_managed_prefix_list" "mycompany_public_cidrs_ipv4" {
  name = "mycompany_public_cidrs_ipv4"
}

data "aws_ec2_managed_prefix_list" "mycompany_vpn_egress_ipv4" {
  name = "mycompany_vpn_egress_ipv4"
}

# --- Lists ---

resource "akamai_clientlist_list" "mycompany_public_cidrs_ipv4" {
  name        = "mycompany_public_cidrs_ipv4" # dev/www.tf looks this name up; keep them in sync
  type        = "IP"
  notes       = "Company public IP ranges, synced from an AWS prefix list by Terraform"
  tags        = ["terraform", "akamai-terraform-example"]
  contract_id = local.clientlist_contract_id
  group_id    = local.clientlist_group_id
  dynamic "items" {
    for_each = tolist(data.aws_ec2_managed_prefix_list.mycompany_public_cidrs_ipv4.entries.*.cidr)
    content {
      value = items.value
    }
  }
}

resource "akamai_clientlist_list" "mycompany_vpn_egress_ipv4" {
  name        = "mycompany_vpn_egress_ipv4"
  type        = "IP"
  notes       = "Company VPN egress IPs, synced from an AWS prefix list by Terraform"
  tags        = ["terraform", "akamai-terraform-example"]
  contract_id = local.clientlist_contract_id
  group_id    = local.clientlist_group_id
  dynamic "items" {
    for_each = tolist(data.aws_ec2_managed_prefix_list.mycompany_vpn_egress_ipv4.entries.*.cidr)
    content {
      value = items.value
    }
  }
}

resource "akamai_clientlist_list" "mycompany_partner_ipv4" {
  name        = "mycompany_partner_ipv4"
  type        = "IP"
  notes       = "Partner IP ranges, maintained in Terraform"
  tags        = ["terraform", "akamai-terraform-example"]
  contract_id = local.clientlist_contract_id
  group_id    = local.clientlist_group_id
  dynamic "items" {
    for_each = local.partner_ipv4
    content {
      value = items.value
    }
  }
}

# --- Activations (each list on both Akamai networks; always the list's current version) ---

resource "akamai_clientlist_activation" "mycompany_public_cidrs_ipv4_stg" {
  list_id  = akamai_clientlist_list.mycompany_public_cidrs_ipv4.list_id
  version  = akamai_clientlist_list.mycompany_public_cidrs_ipv4.version # activate the list's current version
  network  = "STAGING"
  comments = "Managed by Terraform"
}

resource "akamai_clientlist_activation" "mycompany_public_cidrs_ipv4" {
  list_id  = akamai_clientlist_list.mycompany_public_cidrs_ipv4.list_id
  version  = akamai_clientlist_list.mycompany_public_cidrs_ipv4.version # activate the list's current version
  network  = "PRODUCTION"
  comments = "Managed by Terraform"
}

resource "akamai_clientlist_activation" "mycompany_vpn_egress_ipv4_stg" {
  list_id  = akamai_clientlist_list.mycompany_vpn_egress_ipv4.list_id
  version  = akamai_clientlist_list.mycompany_vpn_egress_ipv4.version # activate the list's current version
  network  = "STAGING"
  comments = "Managed by Terraform"
}

resource "akamai_clientlist_activation" "mycompany_vpn_egress_ipv4" {
  list_id  = akamai_clientlist_list.mycompany_vpn_egress_ipv4.list_id
  version  = akamai_clientlist_list.mycompany_vpn_egress_ipv4.version # activate the list's current version
  network  = "PRODUCTION"
  comments = "Managed by Terraform"
}

resource "akamai_clientlist_activation" "mycompany_partner_ipv4_stg" {
  list_id  = akamai_clientlist_list.mycompany_partner_ipv4.list_id
  version  = akamai_clientlist_list.mycompany_partner_ipv4.version # activate the list's current version
  network  = "STAGING"
  comments = "Managed by Terraform"
}

resource "akamai_clientlist_activation" "mycompany_partner_ipv4" {
  list_id  = akamai_clientlist_list.mycompany_partner_ipv4.list_id
  version  = akamai_clientlist_list.mycompany_partner_ipv4.version # activate the list's current version
  network  = "PRODUCTION"
  comments = "Managed by Terraform"
}
