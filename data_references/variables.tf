variable "group_name" {
  description = "Akamai group name. Must exactly match the group name in Akamai Control Center (\"Luna\", control.akamai.com)."
  type        = string

  validation {
    condition     = length(trimspace(var.group_name)) > 0
    error_message = "group_name must be set. Copy terraform.tfvars.example to terraform.tfvars and set your Akamai group name."
  }
}