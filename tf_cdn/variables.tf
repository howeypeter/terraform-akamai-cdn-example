variable "property_name" {
  description = "Name of the Akamai property (also used as the CP code name). Format: lowercase words separated by hyphens, ending in the environment, e.g. mycompany-www-prod."
  type        = string
  validation {
    # Example naming convention; change the pattern (or the list of environments) to match your own.
    condition     = can(regex("^[a-z0-9]+(-[a-z0-9]+)*-(dev|beta|stage|prod)$", var.property_name))
    error_message = "property_name must look like <prefix>-<application>-<env>: lowercase letters, digits, and hyphens, ending in -dev, -beta, -stage, or -prod (e.g. mycompany-www-prod)."
  }
}

variable "group_name" {
  description = "Akamai group name. Must exactly match the group name in Akamai Control Center (\"Luna\", control.akamai.com). Set the default to your group; override it in a module call only for properties in a different group."
  type        = string
  default     = "Example Group Name" # Replace with your Akamai group name.

  validation {
    condition     = length(trimspace(var.group_name)) > 0 && var.group_name != "Example Group Name"
    error_message = "Set group_name: replace the placeholder default in tf_cdn/variables.tf, or pass group_name in the module call."
  }
}

variable "environment" {
  description = "Environment name (dev, beta, stage, or prod). Used in the DataStream lookup and the prod activation rule."
  type        = string
}

variable "contact_email" {
  description = "Email addresses Akamai notifies about property activations. Replace the placeholder with your team's address."
  type        = list(string)
  default     = ["ops@example.com"] # Placeholder (example.com is reserved; mail to it goes nowhere)
}

variable "stage_activation_version" {
  description = "Version active in Akamai-Staging. By default this deploys the latest version to akamai-staging."
  type        = string
  default     = "latest"
}

variable "prod_activation_version" {
  description = "Property version to activate on the Akamai PRODUCTION network. Defaults to the latest version, except when environment = \"prod\", where a specific version number must be set."
  type        = string
  default     = "latest"
}

variable "origin_hostname" {
  description = "Origin hostname (DNS name of your origin server or load balancer)"
  type        = string
}

variable "origin_valid_certs" {
  description = "Valid Certs to accept from Origin"
  type        = list(string)
  default     = ["{{Origin Hostname}}", "{{Forward Host Header}}"]
}

# https://techdocs.akamai.com/property-mgr/docs/origin-server
variable "origin_supports_gzip" {
  description = "Whether to inject gzip towards origin. Enable unless there's a specific need"
  type        = bool
  default     = true
}

variable "edge_hostnames" {
  description = "Map of edge hostnames and corresponding certificate"
  type        = map(string)
}

variable "default_uuid" {
  description = "Some Default Properties require a UUID due to Akamai Custom Rules"
  type        = string
  default     = null
}

variable "rule_nonprod_acl" {
  description = "Template to create an IP allow-list ACL (default deny), typically for nonprod properties"
  default     = null
}

variable "custom_rules" {
  description = "List containing JSON string, for custom Akamai rule"
  type        = list(string)
  default     = []
}

variable "rule_akamai_ps_custom_behavior" {
  description = "Enables a rule that references an Akamai Professional Services custom behavior (ID set in rule_akamai_ps_custom_behavior.tf). Optional attributes: name, rule_uuid (rule UUID), behavior_uuid (behavior UUID)."
  default     = null
}

variable "rule_akamai_ps_advanced" {
  description = "Akamai PS advanced behavior (inline metadata XML). Attributes: custom_xml, rule_uuid (rule UUID), behavior_uuid (behavior UUID), name, description. Must match what Akamai deployed."
  default     = null
}

variable "rule_redirect" {
  description = "HSTS (preferred) plus an HTTP to HTTPS redirect as a failsafe. On by default."
  type = object({
    enable  = optional(bool, true) # whether or not to set HSTS to enabled
    max_age = optional(string, "TEN_MINS")
    # HSTS includeSubDomains: tells browsers to use HTTPS for EVERY subdomain of the hostname, not just this one.
    # Off by default because it can break subdomains that don't serve HTTPS (or use a different or internal
    # certificate), such as internal tools, legacy hosts, or other properties under the same domain. Those would
    # become unreachable over HTTP in browsers for the whole max_age. Enable only once all subdomains serve valid
    # HTTPS. Required (with ONE_YEAR+ max_age) if you want HSTS preload.
    include_sub_domains = optional(bool, false)
    # HSTS preload: only adds the "preload" directive to the header. To actually be preloaded, the domain must
    # also be registered (submitted) at https://hstspreload.org, and it must meet the requirements:
    # max_age of at least ONE_YEAR, includeSubDomains, and HTTPS on every subdomain. Preload applies to the
    # whole registered domain and is slow to undo, so keep it off unless you intend to register the domain.
    preload              = optional(bool, false)
    redirect             = optional(bool, true)
    redirect_status_code = optional(number, 301)
  })
  default = {}
  validation {
    condition = try(contains([
      "ZERO_MINS",
      "TEN_MINS",
      "ONE_DAY",
      "ONE_MONTH",
      "THREE_MONTHS",
      "SIX_MONTHS",
      "ONE_YEAR",
      "TWO_YEARS"
    ], var.rule_redirect.max_age))

    error_message = "max_age must be one of: ZERO_MINS, TEN_MINS, ONE_DAY, ONE_MONTH, THREE_MONTHS, SIX_MONTHS, ONE_YEAR, TWO_YEARS."
  }
}

variable "rule_baseline" {
  description = "Baseline settings applied to every property (caching, performance, HTTP methods, headers, logging/DataStream, mPulse). Optional attributes include default_ttl, strict_rfc_caching, enable_datastream (default false; opt-in), enable_grn, mpulse_api_key, mpulse_exclude_paths."
  default     = null
}

variable "rule_cors" {
  description = "CORS response headers. Optional attributes: allowed_origins (list; default ANY), allow_credentials (default false), methods (default GET, POST), expose_headers, preflight_max_age (default 86400s), criterion.hostname (limit to specific hostnames)."
  default     = null

  validation {
    # Allowing credentials from ANY origin would let any website make logged-in (cookie/client-cert) requests.
    # Browsers also reject a wildcard origin on credentialed requests. Require specific origins instead.
    condition     = !try(var.rule_cors.allow_credentials, false) || length(try(var.rule_cors.allowed_origins, [])) > 0
    error_message = "rule_cors: allow_credentials = true requires allowed_origins (specific origins, e.g. [\"https://www.example.com\"]). Credentials with any origin are unsafe."
  }
}

variable "rule_gzip" {
  description = "Gzip compression on the Akamai edge. Optional attributes: content_types, extensions (each replaces the default list), response (default ALWAYS)."
  default     = null
}

variable "acl_identifier" {
  description = "ACL Identifier - the reason ID MUST match across all rules in the property"
  type        = string
  default     = "mycompany-nonprod-acl"
}
