locals {
  product_id = "prd_Fresca" # Akamai internal codename for ION Property Manager Standard
}

data "akamai_contract" "this" {
  group_name = var.group_name
}

data "akamai_group" "this" {
  group_name  = var.group_name
  contract_id = data.akamai_contract.this.id
}

data "akamai_datastreams" "this" {
  # reformat, since Akamai outputs the group_id as grp_<id>
  group_id = split("_", data.akamai_group.this.id)[1]
}

# OPTIONAL: AWS managed prefix lists as the source of truth for IP allow lists.
#
# If your organization already maintains IP ranges in AWS managed prefix lists (VPN egress,
# office networks, partners, vendors), Terraform data lookups let you reuse those same lists
# for ACLs everywhere Terraform manages them: AWS security groups and WAF, Akamai (this
# module's nonprod ACL, Client Lists), and other providers. Update the prefix list once,
# and every ACL built from it follows on the next apply.
#
# These lookups are commented out so the module doesn't require AWS. To use them:
#   1. Uncomment the lookups you need and replace the names with your own prefix lists.
#   2. Uncomment the matching lines in rule_nonprod_acl.tf.
#   3. Configure the AWS provider and credentials in the calling folder.

# Example: customer-managed prefix list with your company's VPN / remote-access egress IPs.
# data "aws_ec2_managed_prefix_list" "mycompany_vpn_egress_ipv4" {
#   name = "mycompany_vpn_egress_ipv4"
# }

# Example: customer-managed prefix list with your company's office / public IP ranges.
# data "aws_ec2_managed_prefix_list" "mycompany_public_cidrs_ipv4" {
#   name = "mycompany_public_cidrs_ipv4"
# }

# Examples: AWS-managed (official) prefix lists. AWS maintains these; look them up by name.
# Uncomment and reference them in rule_nonprod_acl.tf to use them.

# Route 53 health checker IPs, e.g. to let health checks reach a property behind the ACL.
# data "aws_ec2_managed_prefix_list" "aws_route53_healthchecks" {
#   name = "com.amazonaws.us-east-1.route53-healthchecks"
# }

# CloudFront origin-facing IPs, e.g. when CloudFront sits in front of an Akamai property.
# data "aws_ec2_managed_prefix_list" "aws_cloudfront_origin_facing" {
#   name = "com.amazonaws.global.cloudfront.origin-facing"
# }

# TODO: Add an optional Akamai Client Lists lookup as another source of truth for IP allow lists.
# Client Lists is Akamai's newer list product (recommended over the legacy Network Lists for new work),
# and needs no extra provider. Likely approach (untested): find the list ID with the
# akamai_clientlist_lists data source (filter by name and type = ["IP"]), read it with
# akamai_clientlist_list, and use the IPs from list.items[*].value in rule_nonprod_acl.tf.
# See infra/prod/client_lists.tf for the other half: creating and activating Client Lists in Terraform
# (here, filled from AWS prefix lists).

locals {
  # DataStream lookup by naming convention. This assumes:
  #   - each environment has one DataStream named "datastream-<environment>" (e.g. datastream-dev, datastream-prod), and
  #   - that same stream is used for ALL properties in that environment.
  # Rename your streams to match, or change the name pattern here.
  # Future: this may change to pass in the DataStream name (or ID) as a module input instead.
  datastream_id = [for s in data.akamai_datastreams.this.streams_details : s.stream_id if s.stream_name == "datastream-${var.environment}"]
}

resource "akamai_cp_code" "this" {
  product_id  = local.product_id
  contract_id = data.akamai_contract.this.id
  group_id    = data.akamai_group.this.id
  name        = var.property_name
}

resource "akamai_property" "this" {
  name        = var.property_name
  product_id  = local.product_id
  contract_id = data.akamai_contract.this.id
  group_id    = data.akamai_group.this.id

  rule_format = "v2024-08-13" # Must match the rules builders (rules_v2024_08_13). https://techdocs.akamai.com/terraform/reference/rule-format-changes
  rules       = data.akamai_property_rules_builder.default.json

  dynamic "hostnames" {
    for_each = var.edge_hostnames
    content {
      cname_from             = hostnames.key
      cname_to               = hostnames.value
      cert_provisioning_type = "CPS_MANAGED"
    }
  }
}

resource "akamai_property_activation" "staging" {
  property_id                    = akamai_property.this.id
  contact                        = var.contact_email
  version                        = var.stage_activation_version == "latest" ? akamai_property.this.latest_version : var.stage_activation_version
  network                        = "STAGING"
  auto_acknowledge_rule_warnings = true

  lifecycle {
    ignore_changes = [
      contact
    ]
  }

}

resource "akamai_property_activation" "production" {
  property_id                    = akamai_property.this.id
  contact                        = var.contact_email
  version                        = (var.prod_activation_version == "latest" && var.environment != "prod") ? akamai_property.this.latest_version : var.prod_activation_version
  network                        = "PRODUCTION"
  auto_acknowledge_rule_warnings = true

  lifecycle {
    ignore_changes = [
      contact
    ]
  }
}
