provider "akamai" {}

terraform {
  required_providers {
    akamai = {
      source = "akamai/akamai"
    }
  }
  required_version = ">= 1.3.0"

  # State storage
  # By default, Terraform stores state locally in terraform.tfstate (gitignored).
  # That's fine for trying things out. For shared or CI/CD use, configure a remote
  # backend so state is stored securely, locked during runs, and readable by pipelines.
  #
  # Example: AWS S3. Uncomment, replace the placeholders, then run:
  #   terraform init -migrate-state
  # Backend blocks can't use variables. You can also pass values at init time:
  #   terraform init -backend-config="bucket=<your-bucket>"
  #
  # backend "s3" {
  #   bucket         = "example-terraform-state-bucket"
  #   key            = "akamai/data_references/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}
