provider "akamai" {}

# Alternative: point the provider at a specific .edgerc file / section (see ../../.edgerc.example).
# provider "akamai" {
#   edgerc         = "~/.edgerc"
#   config_section = "default"
# }

locals {
  env           = "dev"
  cert_hostname = "dev.example.com.edgekey.net" # PLACEHOLDER: your Akamai edge hostname (certificate) for dev
  region        = "us-east-1"                   # used by the DataStream S3 destination
}

terraform {
  # State storage: local by default (terraform.tfstate, gitignored). For shared or CI/CD use, configure a
  # remote backend, e.g. AWS S3 (uncomment, replace the placeholders, then run: terraform init -migrate-state).
  #
  # backend "s3" {
  #   bucket         = "example-terraform-state-bucket"
  #   key            = "akamai/infra/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}
