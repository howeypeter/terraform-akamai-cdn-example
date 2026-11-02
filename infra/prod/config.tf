provider "akamai" {}

# Alternative: point the provider at a specific .edgerc file / section (see ../../.edgerc.example).
# provider "akamai" {
#   edgerc         = "~/.edgerc"
#   config_section = "default"
# }

# Needed by client_lists.tf to read AWS managed prefix lists.
provider "aws" {
  region = local.region
}

locals {
  env           = "prod"
  cert_hostname = "example.com.edgekey.net" # PLACEHOLDER: your Akamai edge hostname (certificate) for prod
  region        = "us-east-1"               # AWS region for prefix lists and the DataStream S3 destination
}

terraform {
  # State storage: local by default (terraform.tfstate, gitignored). For shared or CI/CD use, configure a
  # remote backend, e.g. AWS S3 (uncomment, replace the placeholders, then run: terraform init -migrate-state).
  #
  # backend "s3" {
  #   bucket         = "example-terraform-state-bucket"
  #   key            = "akamai/infra/prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}
