# Baseline settings (Property Manager)
#
# The standard child rules every property gets: caching, performance (SureRoute, adaptive acceleration,
# Brotli, timeouts), origin protection (Site Shield), HTTP methods, response headers, logging (report +
# optional DataStream), and mPulse real-user monitoring. Applied to all properties, cacheable or not.
#
# All values here are EXAMPLE defaults. Set your own based on your requirements and consultation with Akamai.
# A platform team can also hard-code values here (removing the input) to enforce them across every property.
#
# Account-specific values are PLACEHOLDERS and must be replaced: the Site Shield map, the SureRoute map,
# and mpulse_api_key (passed per property in the module call).
#
# Related: rule_cors depends on allow_options here; rule_gzip handles edge gzip, while Brotli here caches
# Brotli files from your origin; DataStream logging is opt-in (enable_datastream).

data "akamai_property_rules_builder" "rule_baseline" {
  rules_v2024_08_13 {
    name                  = "Baseline settings"
    comments              = "Policy Template for cache configurations"
    criteria_must_satisfy = "all"
    behavior {
      caching {
        behavior                 = "CACHE_CONTROL"
        default_ttl              = try(var.rule_baseline.default_ttl, "0s")
        must_revalidate          = true
        cache_control_directives = ""
        cacheability_settings    = null
        expiration_settings      = null
        revalidation_settings    = null
        enhanced_rfc_support     = try(var.rule_baseline.strict_rfc_caching, false)
        honor_must_revalidate    = try(var.rule_baseline.strict_rfc_caching, false)
        honor_private            = try(var.rule_baseline.strict_rfc_caching, false)
        honor_max_age            = try(var.rule_baseline.strict_rfc_caching, null)
        honor_s_maxage           = try(var.rule_baseline.strict_rfc_caching, null)
        honor_no_cache           = try(var.rule_baseline.strict_rfc_caching, null)
        honor_no_store           = try(var.rule_baseline.strict_rfc_caching, null)
        honor_proxy_revalidate   = try(var.rule_baseline.strict_rfc_caching, null)
      }
    }
    behavior {
      enhanced_akamai_protocol {
        display = ""
      }
    }
    behavior {
      tiered_distribution {
        enabled = false
      }
    }
    behavior {
      # Site Shield: restricts your origin to a fixed set of Akamai IPs (the Site Shield map), so the origin can
      # block all other traffic. The map is account-specific and provided by Akamai; these values are PLACEHOLDERS.
      site_shield {
        ssmap {
          has_mixed_hosts = false
          name            = "mycompany_acl (s0000.akamaiedge.net)" # PLACEHOLDER: your Site Shield map name
          src             = "PREVIOUS_MAP"
          srmap           = "mycompany-0000.akasrg.akamai.com" # PLACEHOLDER: your SureRoute map (same as custom_map below)
          value           = "s0000.akamaiedge.net"             # PLACEHOLDER: your Site Shield map
        }
      }
    }
    behavior {
      # SureRoute: finds the fastest path from Akamai to your origin. Uses an account-specific map from Akamai (PLACEHOLDER).
      sure_route {
        custom_map             = "mycompany-0000.akasrg.akamai.com" # PLACEHOLDER: your SureRoute map
        enable_custom_key      = false
        enabled                = true
        force_ssl_forward      = false
        race_stat_ttl          = "30m"
        sr_download_link_title = ""
        test_object_url        = "/akamai/sureroute-test-object.html"
        to_host_status         = "INCOMING_HH"
        type                   = "CUSTOM_MAP"
      }
    }
    behavior {
      allow_transfer_encoding {
        enabled = true
      }
    }
    behavior {
      http2 {
        enabled = ""
      }
    }
    behavior {
      modify_outgoing_response_header {
        action                   = "ADD"
        custom_header_name       = "X-CDN"
        header_value             = "Akamai"
        standard_add_header_name = "OTHER"
      }
    }
    behavior {
      set_variable {
        transform      = "LOWER"
        value_source   = "EXPRESSION"
        variable_name  = "PMUSER_PROPERTY"
        variable_value = "{{user.PMUSER_PROPERTY}}"
      }
    }
    behavior {
      set_variable {
        transform        = "LOWER"
        extract_location = "CLIENT_REQUEST_HEADER"
        header_name      = "Origin"
        value_source     = "EXTRACT"
        variable_name    = "PMUSER_HEADER_ORIGIN"
        variable_value   = "{{user.PMUSER_HEADER_ORIGIN}}"
      }
    }
    behavior {
      report {
        custom_log_field     = "{{user.PMUSER_PROPERTY}}_{{user.PMUSER_HEADER_ORIGIN}}_"
        log_accept_language  = false
        log_cookies          = "OFF"
        log_custom_log_field = true
        log_edge_ip          = false
        log_host             = true
        log_referer          = false
        log_user_agent       = true
        log_x_forwarded_for  = false
      }
    }
    # DataStream logging (OPT-IN; off by default).
    #
    # Sends this property's request logs to a DataStream stream, which then delivers them (e.g. to S3 or a SIEM).
    # The stream ID is looked up by name in main.tf using the convention "datastream-<environment>"; create a stream
    # with that name (see infra/<env>/datastream.tf) or change the pattern.
    #
    # To turn it on, in the module call:
    #   rule_baseline = {
    #     enable_datastream = true
    #   }
    #
    # New properties need two steps, because a stream lists the property IDs it collects from:
    #   1. Create the property with enable_datastream = false (the default) and apply.
    #   2. Add the new property's ID to the stream's properties list (infra/<env>/datastream.tf), apply,
    #      then set enable_datastream = true and apply again.
    #
    # Which fields are logged is controlled by the report behavior above (custom field, host, user agent, ...).
    # The sampling (100%) and report fields are EXAMPLE settings; adjust them to your needs.
    dynamic "behavior" {
      for_each = try(var.rule_baseline.enable_datastream, false) ? [1] : []
      content {
        datastream {
          log_enabled         = true
          log_stream_name     = local.datastream_id
          log_stream_title    = ""
          sampling_percentage = 100
          stream_type         = "LOG"
        }
      }
    }
    behavior {
      all_http_in_cache_hierarchy {
        enabled = true
      }
    }
    behavior {
      allow_post {
        allow_without_content_length = false
        enabled                      = true
      }
    }
    behavior {
      allow_options {
        enabled = true
      }
    }
    behavior {
      dns_async_refresh {
        enabled = true
        timeout = "1h"
      }
    }
    behavior {
      timeout {
        value = "5s"
      }
    }
    behavior {
      read_timeout {
        value = "120s"
      }
    }
    behavior {
      cache_tag_visible {
        behavior = "PRAGMA_HEADER"
      }
    }
    behavior {
      allow_put {
        enabled = true
      }
    }
    behavior {
      allow_delete {
        allow_body = true
        enabled    = true
      }
    }
    behavior {
      allow_patch {
        enabled = true
      }
    }
    dynamic "behavior" {
      for_each = try(var.rule_baseline.enable_grn, false) ? [1] : []
      content {
        global_request_number {
          header_name   = "Akamai-GRN"
          output_option = "RESPONSE_HEADER"
        }
      }
    }
    behavior {
      modify_outgoing_response_header {
        action                      = "DELETE"
        custom_header_name          = "X-Powered-By"
        standard_delete_header_name = "OTHER"
      }
    }
    behavior {
      modify_outgoing_response_header {
        action                      = "DELETE"
        custom_header_name          = "Server"
        standard_delete_header_name = "OTHER"
      }
    }
    behavior {
      adaptive_acceleration {
        ab_logic                = "DISABLED"
        ab_testing              = ""
        enable_preconnect       = true
        enable_push             = true
        enable_ro               = false
        preload_enable          = true
        source                  = "mPulse"
        title_http2_server_push = ""
        title_preconnect        = ""
        title_preload           = ""
        title_ro                = ""
      }
    }
    behavior {
      brotli {
        enabled = true
      }
    }
    children = concat(
      [data.akamai_property_rules_builder.mpulse.json],
    )
  }
}

data "akamai_property_rules_builder" "mpulse" {
  rules_v2024_08_13 {
    name                  = "mPulse"
    comments              = "mPulse configuration"
    criteria_must_satisfy = "all"
    dynamic "criterion" {
      for_each = try(length(var.rule_baseline.mpulse_exclude_paths) > 0, false) ? [1] : []
      content {
        path {
          match_operator       = "DOES_NOT_MATCH_ONE_OF"
          match_case_sensitive = false
          normalize            = true
          values               = try(var.rule_baseline.mpulse_exclude_paths, [])
        }
      }
    }
    behavior {
      m_pulse {
        api_key         = try(var.rule_baseline.mpulse_api_key, "")
        buffer_size     = ""
        config_override = ""
        enabled         = true
        loader_version  = "V12"
        require_pci     = false
        title_optional  = ""
      }
    }
  }
}
