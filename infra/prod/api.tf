module "api" {
  source = "../../tf_cdn"

  property_name   = "mycompany-api-${local.env}"
  group_name      = var.group_name # explicit form: from terraform.tfvars (dev relies on the module default)
  origin_hostname = "origin-api.example.com"
  environment     = local.env
  default_uuid    = "default"

  prod_activation_version = 1 # Example: prod is pinned. Bump to the version you've reviewed and want live.

  edge_hostnames = {
    "api.example.com"          = local.cert_hostname
    "accounts-api.example.com" = local.cert_hostname
    "catalog-api.example.com"  = local.cert_hostname # has its own custom rule below
  }

  rule_akamai_ps_advanced = {
    rule_uuid     = "aaaaaaaa-aaaa-aaaa-aaaa-000000000002"
    name          = "Akamai PS advanced: uncompressible status codes"
    behavior_uuid = "bbbbbbbb-bbbb-bbbb-bbbb-000000000002"
    description   = "Status codes Akamai should not compress"
    custom_xml    = "<edgeservices:lma.uncompressable-status-codes>200 201 401 404 409 500 504</edgeservices:lma.uncompressable-status-codes>"
  }

  rule_redirect = {}
  rule_baseline = {}
  custom_rules  = [data.akamai_property_rules_builder.api_custom_rules.json]
  rule_cors = {
    preflight_max_age = "600s"
    allow_credentials = true
    allowed_origins   = ["https://www.example.com"] # Placeholder: the specific sites allowed to send credentials.
  }
}

data "akamai_property_rules_builder" "api_custom_rules" {
  rules_v2024_08_13 {
    name                  = "Custom Configs"
    comments              = ""
    criteria_must_satisfy = "all"
    children = concat(
      [data.akamai_property_rules_builder.api_custom_catalog.json],
    )
  }
}

# Example custom rule for one hostname: vary the cache key by request headers, and override CORS for it.
# custom_rules come after rule_cors in default_rules.tf, so this later rule wins for catalog-api.example.com.
data "akamai_property_rules_builder" "api_custom_catalog" {
  rules_v2024_08_13 {
    name                  = "catalog-api"
    comments              = ""
    criteria_must_satisfy = "all"
    criterion {
      hostname {
        match_operator = "IS_ONE_OF"
        values         = ["catalog-api.example.com"]
      }
    }
    behavior {
      remove_vary {
        enabled = true
      }
    }
    behavior {
      cache_id {
        elements      = ["Accept-Language", "Origin"]
        include_value = true
        optional      = true
        rule          = "INCLUDE_HEADERS"
      }
    }
    behavior {
      cache_id {
        rule = "INCLUDE_ALL_QUERY_PARAMS"
      }
    }
    behavior {
      cache_id {
        rule = "INCLUDE_URL"
      }
    }
    behavior {
      cache_key_query_params {
        behavior = "INCLUDE_ALL_ALPHABETIZE_ORDER"
      }
    }
    behavior {
      cache_tag {
        tag = "mycompany-api-prod-catalog"
      }
    }
    behavior {
      cache_tag_visible {
        behavior = "PRAGMA_HEADER"
      }
    }
    behavior {
      cors_support {
        allow_credentials = false
        allow_headers     = "ANY"
        allow_origins     = "ANY"
        enabled           = true
        expose_headers    = ["*"]
        methods           = ["GET", "POST"]
        preflight_max_age = "3600s"
      }
    }
  }
}
