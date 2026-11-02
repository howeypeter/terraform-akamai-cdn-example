# data_references

Akamai's APIs, and the Akamai Terraform provider built on them, often need values that are hard to find:
IDs that Akamai Control Center doesn't show, and internal names and codes that don't match the product names you see in the portal.
This folder uses read-only Terraform data sources to surface those values in one place.
It's a debugging and discovery tool: run it when you need to find an ID or check what Akamai actually has configured.

It never creates or changes Akamai resources.

## Why use it

- **Find hidden IDs.** Property IDs, contract and group IDs, include IDs, CP codes, and DataStream IDs are often
  required by the provider (for example, by `terraform import`), but aren't shown in Control Center.
  For example, `datastream_lookup` lists the stream ID you need to link properties to a DataStream log stream.
- **Track your configuration over time.** Running these lookups records the current IDs, hostnames, and settings in the Terraform
  state and outputs. Your CI/CD tooling can read them with `terraform output -json`.
- **Map Akamai's internal names and codes.** The APIs often use internal names that don't match the product names in the portal.
  For example, Control Center was formerly called "Luna", and the product ID `prd_Fresca` refers to Ion Standard.
  The outputs show the raw values the provider expects.

## What it looks up

| Output | Description |
|---|---|
| `contracts`, `contract_id`, `contract_info` | Contracts available to your API client, and the contract for your group |
| `groups`, `group_id`, `group_info` | Groups available to your API client, and your group's details |
| `properties` | Properties in the group, with property IDs and versions |
| `property_hostnames` | Hostnames and edge hostnames for each property |
| `get_all_includes` | Property Manager includes in the group |
| `datastream_lookup` | All DataStream streams in the group, with their names and stream IDs (for debugging and finding stream IDs) |
| `network_lists` | Network lists available to your API client |

## Usage

1. Set up Akamai API credentials in `~/.edgerc`, or with the `AKAMAI_*` environment variables.
   See [`../.edgerc.example`](../.edgerc.example).
2. Set your group name:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   Edit `group_name` to exactly match your group name in Akamai Control Center.
3. Run:
   ```bash
   terraform init
   terraform plan    # preview the lookups and output values locally; nothing is saved to state
   terraform apply   # save the outputs to state
   terraform output  # read the saved outputs
   ```
   Data sources are read during `plan`, so the output values appear under "Changes to Outputs" before anything is applied.
   Neither command creates or changes anything in Akamai.

   To read a single output as JSON, for example in a CI/CD pipeline:
   ```bash
   terraform output -json datastream_lookup
   ```

   State is stored locally by default. To share the outputs with CI/CD, enable the example remote backend
   in `config.tf` (or configure your own) and run `terraform init -migrate-state`.

Requires Terraform 1.3 or later.
