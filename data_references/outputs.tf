output "contracts" {
  value = data.akamai_contracts.this
}

output "contract_id" {
  value = data.akamai_contract.this.id
}

output "groups" {
  value = data.akamai_groups.this
}

output "group_id" {
  value = data.akamai_group.this.id
}

output "contract_info" {
  value = data.akamai_contract.this
}

output "group_info" {
  value = data.akamai_group.this
}

output "properties" {
  value = data.akamai_properties.this
}

output "get_all_includes" {
  value = data.akamai_property_includes.this
}

# Reference: uncomment along with data "akamai_cp_codes" in data.tf.
# output "cp_codes" {
#   description = "CP codes in the selected group, with their IDs and names."
#   value       = data.akamai_cp_codes.this.cp_codes
# }

# Debugging helper: lists every DataStream in the group with its stream ID.
# Use it to find the stream ID to reference when linking properties to a stream
# (the DataStream behavior), since the ID isn't easy to find in Control Center.

output "datastream_lookup" {
  description = "DataStream names and IDs in the selected group (for debugging and finding stream IDs)."
  value = [
    for s in data.akamai_datastreams.this.streams_details : {
      stream_name = s.stream_name
      stream_id   = s.stream_id
    }
  ]
}

output "network_lists" {
  value = data.akamai_networklist_network_lists.this
}

output "property_hostnames" {
  value = data.akamai_property_hostnames.this
}
