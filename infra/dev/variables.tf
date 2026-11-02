variable "group_name" {
  description = "Akamai group name. Must exactly match the group name in Akamai Control Center (\"Luna\", control.akamai.com)."
  type        = string

  validation {
    condition     = length(trimspace(var.group_name)) > 0
    error_message = "group_name must be set. Copy terraform.tfvars.example to terraform.tfvars and set your Akamai group name."
  }
}

variable "datastream_s3_access_key" {
  description = "AWS access key ID for the DataStream S3 destination. Set in terraform.tfvars (gitignored) or TF_VAR_datastream_s3_access_key."
  type        = string
  sensitive   = true
}

variable "datastream_s3_secret_key" {
  description = "AWS secret access key for the DataStream S3 destination. Set in terraform.tfvars (gitignored) or TF_VAR_datastream_s3_secret_key."
  type        = string
  sensitive   = true
}
