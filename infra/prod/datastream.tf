# DataStream: delivers Akamai request logs for this environment (here, to S3).
#
# Properties send logs to this stream only when enable_datastream = true in their rule_baseline input
# (it's opt-in; www.tf turns it on). The tf_cdn module finds the stream by name, "datastream-<environment>",
# so keep stream_name in that form. A stream lists the property IDs it collects from, so new properties take
# two steps: create the property, add its ID to `properties` below, then set enable_datastream = true.

# Contract and group IDs are looked up from the Akamai group name (var.group_name, set in terraform.tfvars).
# Also used by client_lists.tf.
data "akamai_contract" "this" {
  group_name = var.group_name
}

data "akamai_group" "this" {
  group_name  = var.group_name
  contract_id = data.akamai_contract.this.id
}

resource "akamai_datastream" "this" {
  active = true
  delivery_configuration {
    format = "JSON"
    frequency {
      interval_in_secs = 30
    }
    upload_file_prefix = "ak"
    upload_file_suffix = "ds"
  }
  contract_id = data.akamai_contract.this.id

  # DataSet Fields: https://techdocs.akamai.com/terraform/docs/set-up-datastream
  dataset_fields = [
    # Log information
    1000, # CP code
    1002, # Request ID
    1100, # Request Time
    # Message exchange data
    1006, # Client IP
    1008, # HTTP status code
    1011, # Request host
    1012, # Request method
    1013, # Request path
    1017, # User-Agent
    2008, # Total bytes
    2009, # Query String
    # Request header data
    1032, # Referer
    1037, # X-Forwarded-For
    2005, # Max-Age
    # Network performance data
    1068, # Error code
    1102, # Turn around time
    2022, # Asnum
    2025, # Time to first byte
    # Cache data
    2010, # Cache status
    2019, # Cacheable
    # Geo data
    2012, # Country/Region
    # Web security
    2050, # Security rules
    # Custom fields
    1082, # Custom field
  ]
  # Akamai returns the group ID as grp_<id>; DataStream wants just <id>.
  group_id = split("_", data.akamai_group.this.id)[1]
  properties = [
    "0000001", # PLACEHOLDER: property ID of a property that logs to this stream
    "0000002", # PLACEHOLDER: find property IDs with data_references (properties output)
  ]
  stream_name = "datastream-${local.env}"
  s3_connector {
    # Keys come from sensitive variables (terraform.tfvars, gitignored, or TF_VAR_* in CI). Never commit them.
    # Note: Terraform state still stores them in plain text, so protect your state (encrypted, access-restricted).
    access_key        = var.datastream_s3_access_key
    secret_access_key = var.datastream_s3_secret_key
    bucket            = "example-akamai-datastream-logs" # PLACEHOLDER: your S3 bucket
    display_name      = "datastream-${local.env}"
    path              = "akamai/${local.env}/datastream"
    region            = local.region
  }

  notification_emails = [
    "ops@example.com",
  ]
  collect_midgress = false

  lifecycle {
    # Keys are often rotated outside Terraform; don't overwrite them on every apply.
    # To rotate keys through Terraform, remove this temporarily, update terraform.tfvars, and apply.
    ignore_changes = [
      s3_connector
    ]
  }
}
