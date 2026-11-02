# Akamai Terraform example

An example of managing Akamai CDN properties with the [Akamai Terraform provider](https://techdocs.akamai.com/terraform/docs).
It includes a reusable property module (`tf_cdn/`), example properties for a `dev` and a `prod` environment
(`infra/`), and a read-only helper for finding Akamai IDs (`data_references/`).

> **This is an example, not a recommended production baseline.** Every default (TTLs, gzip types, HSTS
> settings, CORS, ACL IPs, logging fields) is an illustration. Set your own values based on your requirements
> and consultation with Akamai (your account team or Professional Services).

## Contents

- [Repository layout](#repository-layout)
- [Requirements](#requirements)
- [Authentication](#authentication)
- [Quick start](#quick-start)
- [Placeholders you must replace](#placeholders-you-must-replace)
- [State storage](#state-storage)
- [Using the module](#using-the-module)
- [Rule order and priority](#rule-order-and-priority)
- [Activation: Akamai networks vs. your environments](#activation-akamai-networks-vs-your-environments)
- [HTTPS enforcement (HSTS and redirect)](#https-enforcement-hsts-and-redirect)
- [IP access control (ACLs) and Client Lists](#ip-access-control-acls-and-client-lists)
- [CORS](#cors)
- [Logging with DataStream](#logging-with-datastream)
- [Akamai Professional Services behaviors](#akamai-professional-services-behaviors)
- [Importing existing resources](#importing-existing-resources)
- [Known limitations and TODOs](#known-limitations-and-todos)
- [Regenerating the module docs](#regenerating-the-module-docs)
- [Module reference](#module-reference) (generated)

## Repository layout

| Path | What it is |
|---|---|
| `tf_cdn/` | The property module: property, CP code, activations, and a set of optional rule templates (`rule_*.tf`). |
| `infra/dev/` | Example `dev` environment: two properties (`www.tf`, `api.tf`) and a DataStream stream. |
| `infra/prod/` | Example `prod` environment: the same two properties, a DataStream stream, and the Client Lists (`client_lists.tf`). |
| `data_references/` | Read-only lookups to find contract, group, property, DataStream, and other IDs. See its [README](data_references/README.md). |
| `.edgerc.example` | Placeholder Akamai API credentials file. |
| `.tool-versions`, `.terraform-version` | Pinned minimum Terraform version (1.3.10) for asdf/mise and tfenv/tfswitch. |

`dev` and `prod` intentionally show different ways to do the same thing (for example, relying on a module
default in `dev` and passing a value explicitly in `prod`), so you can compare them.

## Requirements

- **Terraform 1.3 or later.** The minimum is enforced by `required_version` in each root folder. Install it any way you like:
  - Homebrew: `brew tap hashicorp/tap && brew install hashicorp/tap/terraform`
  - tfenv or tfswitch (reads `.terraform-version`), asdf or mise (reads `.tool-versions`)
- **An Akamai account** with an API client (see [Authentication](#authentication)).
- **AWS credentials, only for `infra/prod/client_lists.tf`**, which reads AWS managed prefix lists. The module and
  `infra/dev` don't need AWS.

## Authentication

1. In Akamai Control Center, create an API client: **Identity & Access Management → API clients → Create API client**.
   Give it access to the APIs used here: Property Manager (PAPI), CP Codes, DataStream, Client Lists, and
   (for `data_references`) Network Lists.
2. Give Terraform the credentials, either:
   - **Locally:** copy [`.edgerc.example`](.edgerc.example) to `~/.edgerc` and fill it in. The provider reads the
     `[default]` section by default. `infra/*/config.tf` shows how to point at another file or section.
   - **In CI/CD:** set `AKAMAI_HOST`, `AKAMAI_CLIENT_TOKEN`, `AKAMAI_CLIENT_SECRET`, and `AKAMAI_ACCESS_TOKEN`.

Never commit a real `.edgerc`, `terraform.tfvars`, or state file. `.gitignore` already excludes them.

## Quick start

```bash
cd infra/dev
cp terraform.tfvars.example terraform.tfvars   # set group_name and the DataStream keys
terraform init
terraform plan
```

The first `plan` stops until you replace the placeholders. That's deliberate: see the next section.
Apply `infra/prod` before `infra/dev` if you use the shared Client List lookup (see [ACLs](#ip-access-control-acls-and-client-lists)).

## Placeholders you must replace

The example uses placeholders that **fail safely**: they're rejected or match nothing until you replace them.

| Placeholder | Where | Replace with |
|---|---|---|
| `group_name = "Example Group Name"` | `tf_cdn/variables.tf` (module default) and `infra/*/terraform.tfvars` | Your Akamai group name, exactly as shown in Control Center |
| `example.com` / `example.net` hostnames, `*.edgekey.net` edge hostnames | `infra/*/www.tf`, `api.tf`, `config.tf` | Your hostnames and edge hostnames |
| Site Shield map `s0000.akamaiedge.net`, SureRoute map `mycompany-0000.akasrg.akamai.com` | `tf_cdn/rule_baseline.tf` | Your account's maps (from Akamai) |
| `XXXXX-XXXXX-XXXXX-XXXXX-0000N` mPulse API keys | `infra/prod/www.tf` | Your mPulse keys |
| `cbe_000000000` custom behavior ID | `tf_cdn/rule_akamai_ps_custom_behavior.tf` | The ID Akamai PS gives you |
| `aaaaaaaa-…` / `bbbbbbbb-…` UUIDs | `rule_akamai_ps_advanced` inputs in `infra/*` | The UUIDs of the deployed rule/behavior |
| RFC 5737 IPs (`192.0.2.x`, `198.51.100.x`, `203.0.113.x`) | `tf_cdn/rule_nonprod_acl.tf`, `infra/prod/client_lists.tf` | Your real IP ranges |
| Property IDs `0000001`, S3 bucket, `REPLACE_ME` keys | `infra/*/datastream.tf`, `terraform.tfvars` | Your values |
| `ops@example.com` | `tf_cdn/variables.tf` (`contact_email`) | Your team's address |

`terraform validate` in `infra/dev` reports the `group_name` placeholder as an error until you replace the module
default; `infra/prod` passes `group_name` from its tfvars, so `validate` succeeds there and `plan` catches it.

## State storage

By default each root folder keeps state locally in `terraform.tfstate` (gitignored). That's fine for trying
things out. **For shared or CI/CD use, configure a remote backend** so state is encrypted, locked during runs,
and readable by your pipelines. State can contain secrets (for example the DataStream S3 keys), so restrict access.

Each `config.tf` contains a commented-out AWS S3 backend example. To switch, uncomment it, replace the
placeholders, and run `terraform init -migrate-state`. Any Terraform backend works (GCS, Azure, HCP Terraform, ...).

## Using the module

A property is one module call:

```hcl
module "www" {
  source = "../../tf_cdn"

  property_name   = "mycompany-www-${local.env}"
  environment     = local.env
  origin_hostname = "origin-www.dev.example.com"

  edge_hostnames = {
    "www.dev.example.com" = local.cert_hostname
  }

  rule_redirect = {}                              # HSTS + HTTPS redirect, with defaults
  rule_baseline = { enable_datastream = true }    # baseline settings, overriding one default
  rule_gzip     = {}
}
```

The optional rule templates:

| Input | File | What it adds |
|---|---|---|
| `rule_baseline` | `rule_baseline.tf` | Standard settings for every property: caching, performance, Site Shield, HTTP methods, response headers, logging, mPulse |
| `rule_redirect` | `rule_redirect.tf` | HSTS plus an HTTP→HTTPS redirect (on by default) |
| `rule_gzip` | `rule_gzip.tf` | Edge gzip for text content types and extensions |
| `rule_cors` | `rule_cors.tf` | CORS response headers (credentials require specific origins) |
| `rule_nonprod_acl` | `rule_nonprod_acl.tf` | A secondary IP allow-list ACL (default deny) |
| `rule_akamai_ps_custom_behavior` | `rule_akamai_ps_custom_behavior.tf` | References an Akamai PS custom behavior by ID |
| `rule_akamai_ps_advanced` | `rule_akamai_ps_advanced.tf` | Carries Akamai PS advanced behavior XML |
| `custom_rules` | your own `akamai_property_rules_builder` | Any other rules (see `infra/prod/api.tf`) |

A template is included when its input is set (`{}` uses all defaults); leave it unset or `null` to skip it
(`rule_redirect` is the exception: it defaults to `{}`, see [Known limitations](#known-limitations-and-todos)).

### Defaults are choices

The module sets opinionated defaults so a property works with very little input. You can adopt it two ways:

- **Overridable defaults (as shipped):** teams accept the defaults and override them per property where needed.
- **Platform-enforced settings:** a platform team can hard-code values in the module (remove the input, or set the
  value directly in the rule) so every property in the company gets the same setting, with no way to override it.
  This keeps the CDN configuration consistent, for example always enforcing HSTS and the HTTPS redirect.

A reasonable split: lock down security baselines (HTTPS enforcement, ACL behavior), and leave performance
settings (caching, gzip, CORS details) flexible.

The group name is an example: `tf_cdn` has a placeholder default, so `dev` relies on it, while `prod` passes
`group_name = var.group_name` from its tfvars. Both work.

## Rule order and priority

Property Manager evaluates rules **top to bottom**, and every matching rule applies. When two matching rules set
the same behavior, **the later (lower) rule wins.** Order therefore matters.

The module's child rules (see `tf_cdn/default_rules.tf`) are, in order:

1. PS custom behavior → 2. PS advanced → 3. redirect → 4. baseline → 5. gzip → 6. CORS →
7. your `custom_rules` → 8. nonprod ACL (**last**, so the ACL decision overrides everything above it).

For example, `infra/prod/api.tf` has a custom rule for `catalog-api.example.com` that sets its own CORS headers;
because `custom_rules` come after `rule_cors`, the custom rule wins for that hostname. Put new rules where they
should override (later) or be overridden (earlier); reordering changes behavior.

## Activation: Akamai networks vs. your environments

Akamai has two **networks**, `STAGING` and `PRODUCTION`. These are separate from your own `dev`/`prod`
**environments**: every property, in every environment, is activated on both Akamai networks.

| | Akamai STAGING network | Akamai PRODUCTION network |
|---|---|---|
| `dev` (any non-prod environment) | latest version, every apply | latest version, every apply |
| `prod` | latest version, every apply | **only the pinned `prod_activation_version`** |

So in `prod`, a change creates a new property version and activates it on STAGING; it reaches PRODUCTION only
when you review it (for example in Control Center) and bump `prod_activation_version`. If `environment = "prod"`
and the version is left at `"latest"`, Terraform fails with a type error, on purpose.
`ignore_changes = [contact]` means changing `contact_email` alone doesn't trigger a re-activation.

## HTTPS enforcement (HSTS and redirect)

`rule_redirect` uses Akamai's HSTS behavior:

- **HSTS** (preferred): browsers that have seen the header upgrade later requests to HTTPS themselves.
- **The built-in redirect** (`redirect = true`, 301) is the failsafe: it ensures content is never served over plain
  HTTP, for first visits and clients that ignore HSTS. Keep it on unless something else blocks HTTP.
- `include_sub_domains` and `preload` are **off by default**. `includeSubDomains` can break subdomains without valid
  HTTPS; preload also requires registering the domain at [hstspreload.org](https://hstspreload.org) and is slow to undo.

The real way around HTTPS (or any edge control) is to call your origin directly. Make the origin accept only
Akamai traffic, for example with Site Shield (in `rule_baseline`), an origin IP allow list, or a shared secret
header. Also mark cookies `Secure`.

## IP access control (ACLs) and Client Lists

`rule_nonprod_acl` adds a **secondary**, property-level allow list (default deny, then allow listed IPs). **Primary**
IP access control belongs in Akamai's WAF, App & API Protector (IP/Geo Firewall), using Client Lists or legacy
Network Lists.

Where the ACL's IPs can come from:

| Source | Where |
|---|---|
| Module defaults (placeholders): Akamai support IPs, VPN / testing-tool IPs | `tf_cdn/rule_nonprod_acl.tf` |
| `rule_nonprod_acl.allowed_ips` / `custom_acl` from the caller | `infra/dev/www.tf` |
| AWS managed prefix lists (optional, commented out) | `tf_cdn/main.tf`, `rule_nonprod_acl.tf` |
| An Akamai Client List read by name (optional, commented out) | `infra/dev/www.tf` |

**Client Lists are account-level** and are managed in one place, `infra/prod/client_lists.tf`, which creates them
(from AWS prefix lists or a hard-coded list) and activates them on both networks. `infra/dev/www.tf` shows how dev
can read one by name and feed its IPs into the ACL. Property rules can't reference a Client List directly, so the
lookup passes the IPs as `allowed_ips`. **Apply `infra/prod` first**, and keep the list name the same in both places.

## CORS

`rule_cors` adds CORS headers (defaults: any origin, `GET`/`POST`, no credentials). If you set
`allow_credentials = true`, the module **requires** `allowed_origins`: credentials from any origin would let any
website make logged-in requests.

Choosing `allowed_origins`: **your application code and configuration are the authoritative source.** List every
site that calls the property. As a secondary cross-check only, `rule_baseline` logs the request `Origin` header in
the DataStream custom log field; collect it *before* restricting origins and over weeks or more. Once origins are
restricted, browsers block disallowed sites, so those requests mostly no longer show up in the logs.

CORS preflight requests use `OPTIONS`, which `rule_baseline` allows (`allow_options`); use `rule_cors` together
with `rule_baseline` or allow OPTIONS another way.

## Logging with DataStream

Logging is **opt-in**.

1. **Create a stream per environment** named `datastream-<environment>` (see `infra/<env>/datastream.tf`), or change
   the name pattern in `tf_cdn/main.tf`. The S3 keys come from sensitive variables in `terraform.tfvars`.
2. **Turn it on per property:** `rule_baseline = { enable_datastream = true }`.
3. **New properties take two applies:** a stream lists the property IDs it collects from, so create the property
   with logging off, add its property ID to the stream's `properties`, then set `enable_datastream = true`.
4. **What's logged:** the `report` behavior in `rule_baseline.tf` (custom field `<property>_<origin>_`, host, user
   agent) and the stream's `dataset_fields`. Both are examples.

Find stream IDs and property IDs with [`data_references`](data_references/README.md).

## Akamai Professional Services behaviors

Some settings can only be provided by Akamai (Professional Services or your account team):

- **Custom behaviors** (`rule_akamai_ps_custom_behavior`): Akamai gives you an ID (`cbe_…`), which you hard-code in the rule.
- **Advanced behaviors** (`rule_akamai_ps_advanced`): raw metadata XML that Terraform must send back exactly as
  deployed, with its rule and behavior UUIDs when present.

Both files explain how to bring an existing Akamai-deployed behavior under Terraform.

## Importing existing resources

```bash
terraform import module.<name>.akamai_property.this prp_<property-id>
terraform import module.<name>.akamai_cp_code.this <cp-code-id>,ctr_<contract-id>,grp_<group-id>
terraform import module.<name>.akamai_property_activation.staging prp_<property-id>:STAGING
terraform import module.<name>.akamai_property_activation.production prp_<property-id>:PRODUCTION
```

## Known limitations and TODOs

- `rule_redirect = null` doesn't disable the redirect rule (it fails); leave it set or omit it.
- Brotli (`rule_baseline`) caches Brotli files from your origin; it may move into `rule_gzip` later.
- `rule_baseline` enables `PUT`, `DELETE`, and `PATCH` for every property; restrict this for static sites if you prefer.
- The Client List lookup in `infra/dev/www.tf` and the ID conversion in `infra/prod/client_lists.tf` haven't been
  tested against a live account.
- The provider version isn't pinned; pin it in the root folders' `versions.tf` for repeatable builds.

## Regenerating the module docs

The [Module reference](#module-reference) below is generated by [terraform-docs](https://terraform-docs.io).
After changing `tf_cdn/`, regenerate it:

```bash
cd tf_cdn
terraform-docs .
```

## Module reference

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_akamai"></a> [akamai](#provider\_akamai) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [akamai_cp_code.this](https://registry.terraform.io/providers/akamai/akamai/latest/docs/resources/cp_code) | resource |
| [akamai_property.this](https://registry.terraform.io/providers/akamai/akamai/latest/docs/resources/property) | resource |
| [akamai_property_activation.production](https://registry.terraform.io/providers/akamai/akamai/latest/docs/resources/property_activation) | resource |
| [akamai_property_activation.staging](https://registry.terraform.io/providers/akamai/akamai/latest/docs/resources/property_activation) | resource |
| [akamai_contract.this](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/contract) | data source |
| [akamai_datastreams.this](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/datastreams) | data source |
| [akamai_group.this](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/group) | data source |
| [akamai_property_rules_builder.acl_allow_akamai_support_ips](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/property_rules_builder) | data source |
| [akamai_property_rules_builder.acl_allow_mycompany_vpn_egress](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/property_rules_builder) | data source |
| [akamai_property_rules_builder.default](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/property_rules_builder) | data source |
| [akamai_property_rules_builder.mpulse](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/property_rules_builder) | data source |
| [akamai_property_rules_builder.rule_akamai_ps_advanced](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/property_rules_builder) | data source |
| [akamai_property_rules_builder.rule_akamai_ps_custom_behavior](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/property_rules_builder) | data source |
| [akamai_property_rules_builder.rule_baseline](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/property_rules_builder) | data source |
| [akamai_property_rules_builder.rule_cors](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/property_rules_builder) | data source |
| [akamai_property_rules_builder.rule_gzip](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/property_rules_builder) | data source |
| [akamai_property_rules_builder.rule_nonprod_acl](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/property_rules_builder) | data source |
| [akamai_property_rules_builder.rule_redirect](https://registry.terraform.io/providers/akamai/akamai/latest/docs/data-sources/property_rules_builder) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_edge_hostnames"></a> [edge\_hostnames](#input\_edge\_hostnames) | Map of edge hostnames and corresponding certificate | `map(string)` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name (dev, beta, stage, or prod). Used in the DataStream lookup and the prod activation rule. | `string` | n/a | yes |
| <a name="input_origin_hostname"></a> [origin\_hostname](#input\_origin\_hostname) | Origin hostname (DNS name of your origin server or load balancer) | `string` | n/a | yes |
| <a name="input_property_name"></a> [property\_name](#input\_property\_name) | Name of the Akamai property (also used as the CP code name). Format: lowercase words separated by hyphens, ending in the environment, e.g. mycompany-www-prod. | `string` | n/a | yes |
| <a name="input_acl_identifier"></a> [acl\_identifier](#input\_acl\_identifier) | ACL Identifier - the reason ID MUST match across all rules in the property | `string` | `"mycompany-nonprod-acl"` | no |
| <a name="input_contact_email"></a> [contact\_email](#input\_contact\_email) | Email addresses Akamai notifies about property activations. Replace the placeholder with your team's address. | `list(string)` | <pre>[<br/>  "ops@example.com"<br/>]</pre> | no |
| <a name="input_custom_rules"></a> [custom\_rules](#input\_custom\_rules) | List containing JSON string, for custom Akamai rule | `list(string)` | `[]` | no |
| <a name="input_default_uuid"></a> [default\_uuid](#input\_default\_uuid) | Some Default Properties require a UUID due to Akamai Custom Rules | `string` | `null` | no |
| <a name="input_group_name"></a> [group\_name](#input\_group\_name) | Akamai group name. Must exactly match the group name in Akamai Control Center ("Luna", control.akamai.com). Set the default to your group; override it in a module call only for properties in a different group. | `string` | `"Example Group Name"` | no |
| <a name="input_origin_supports_gzip"></a> [origin\_supports\_gzip](#input\_origin\_supports\_gzip) | Whether to inject gzip towards origin. Enable unless there's a specific need | `bool` | `true` | no |
| <a name="input_origin_valid_certs"></a> [origin\_valid\_certs](#input\_origin\_valid\_certs) | Valid Certs to accept from Origin | `list(string)` | <pre>[<br/>  "{{Origin Hostname}}",<br/>  "{{Forward Host Header}}"<br/>]</pre> | no |
| <a name="input_prod_activation_version"></a> [prod\_activation\_version](#input\_prod\_activation\_version) | Property version to activate on the Akamai PRODUCTION network. Defaults to the latest version, except when environment = "prod", where a specific version number must be set. | `string` | `"latest"` | no |
| <a name="input_rule_akamai_ps_advanced"></a> [rule\_akamai\_ps\_advanced](#input\_rule\_akamai\_ps\_advanced) | Akamai PS advanced behavior (inline metadata XML). Attributes: custom\_xml, rule\_uuid (rule UUID), behavior\_uuid (behavior UUID), name, description. Must match what Akamai deployed. | `any` | `null` | no |
| <a name="input_rule_akamai_ps_custom_behavior"></a> [rule\_akamai\_ps\_custom\_behavior](#input\_rule\_akamai\_ps\_custom\_behavior) | Enables a rule that references an Akamai Professional Services custom behavior (ID set in rule\_akamai\_ps\_custom\_behavior.tf). Optional attributes: name, rule\_uuid (rule UUID), behavior\_uuid (behavior UUID). | `any` | `null` | no |
| <a name="input_rule_baseline"></a> [rule\_baseline](#input\_rule\_baseline) | Baseline settings applied to every property (caching, performance, HTTP methods, headers, logging/DataStream, mPulse). Optional attributes include default\_ttl, strict\_rfc\_caching, enable\_datastream (default false; opt-in), enable\_grn, mpulse\_api\_key, mpulse\_exclude\_paths. | `any` | `null` | no |
| <a name="input_rule_cors"></a> [rule\_cors](#input\_rule\_cors) | CORS response headers. Optional attributes: allowed\_origins (list; default ANY), allow\_credentials (default false), methods (default GET, POST), expose\_headers, preflight\_max\_age (default 86400s), criterion.hostname (limit to specific hostnames). | `any` | `null` | no |
| <a name="input_rule_gzip"></a> [rule\_gzip](#input\_rule\_gzip) | Gzip compression on the Akamai edge. Optional attributes: content\_types, extensions (each replaces the default list), response (default ALWAYS). | `any` | `null` | no |
| <a name="input_rule_nonprod_acl"></a> [rule\_nonprod\_acl](#input\_rule\_nonprod\_acl) | Template to create an IP allow-list ACL (default deny), typically for nonprod properties | `any` | `null` | no |
| <a name="input_rule_redirect"></a> [rule\_redirect](#input\_rule\_redirect) | HSTS (preferred) plus an HTTP to HTTPS redirect as a failsafe. On by default. | <pre>object({<br/>    enable  = optional(bool, true) # whether or not to set HSTS to enabled<br/>    max_age = optional(string, "TEN_MINS")<br/>    # HSTS includeSubDomains: tells browsers to use HTTPS for EVERY subdomain of the hostname, not just this one.<br/>    # Off by default because it can break subdomains that don't serve HTTPS (or use a different or internal<br/>    # certificate), such as internal tools, legacy hosts, or other properties under the same domain. Those would<br/>    # become unreachable over HTTP in browsers for the whole max_age. Enable only once all subdomains serve valid<br/>    # HTTPS. Required (with ONE_YEAR+ max_age) if you want HSTS preload.<br/>    include_sub_domains = optional(bool, false)<br/>    # HSTS preload: only adds the "preload" directive to the header. To actually be preloaded, the domain must<br/>    # also be registered (submitted) at https://hstspreload.org, and it must meet the requirements:<br/>    # max_age of at least ONE_YEAR, includeSubDomains, and HTTPS on every subdomain. Preload applies to the<br/>    # whole registered domain and is slow to undo, so keep it off unless you intend to register the domain.<br/>    preload              = optional(bool, false)<br/>    redirect             = optional(bool, true)<br/>    redirect_status_code = optional(number, 301)<br/>  })</pre> | `{}` | no |
| <a name="input_stage_activation_version"></a> [stage\_activation\_version](#input\_stage\_activation\_version) | Version active in Akamai-Staging. By default this deploys the latest version to akamai-staging. | `string` | `"latest"` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_data_output"></a> [data\_output](#output\_data\_output) | Placeholder output; see the comments in output.tf for examples. |
<!-- END_TF_DOCS -->
