# Gzip compression (Property Manager)
#
# Akamai gzips matching responses at the edge, for clients that accept gzip. A response is compressed if its
# Content-Type OR its file extension matches (criteria_must_satisfy = "any").
#
# The content types, extensions, and response setting below are EXAMPLE defaults; set your own. Passing
# content_types or extensions in the module call REPLACES the default list (it doesn't add to it).
#
# Related settings elsewhere in this module:
#   - Brotli: enabled in rule_baseline.tf. It caches Brotli files your ORIGIN produces; it doesn't compress
#     at the edge. (TODO: decide whether Brotli belongs in this rule.)
#   - origin_supports_gzip (default_rules.tf): whether Akamai asks your origin for compressed responses.

data "akamai_property_rules_builder" "rule_gzip" {
  rules_v2024_08_13 {
    name                  = "Gzip compression"
    comments              = "Default policy to gzip certain files on the Akamai edge"
    criteria_must_satisfy = "any"
    criterion {
      response_header {
        header_name                = "Content-Type"
        match_case_sensitive_value = false
        match_operator             = "IS_ONE_OF"
        match_wildcard_name        = false
        match_wildcard_value       = true
        values = try(var.rule_gzip.content_types,
          [
            "text/html*",
            "application/javascript*",   # current standard JavaScript type
            "text/javascript*",          # also widely used (and the type the HTML spec now recommends)
            "application/x-javascript*", # legacy; kept for older origins
            "text/css*",
            "application/json*",
          ]
        )
      }
    }
    criterion {
      file_extension {
        match_case_sensitive = false
        match_operator       = "IS_ONE_OF"
        values = try(var.rule_gzip.extensions,
          [
            "action",
            "ashx",
            "asmx",
            "asp",
            "aspx",
            "atf",
            "axd",
            "cfm",
            "conf",
            "css",
            "css3",
            "csv",
            "do",
            "doc",
            "docx",
            "htm",
            "html",
            "js",
            "jsf",
            "json",
            "jsp",
            "pdf",
            "php",
            "portal",
            "rss",
            "rtf",
            "svg",
            "svgz",
            "tsv",
            "text",
            "txt",
            "xhtml",
            "xml",
            "xsl",
            "xslt",
          ]
        )
      }
    }
    behavior {
      gzip_response {
        behavior = try(var.rule_gzip.response, "ALWAYS")
      }
    }
  }
}
