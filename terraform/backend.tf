terraform {
  backend "s3" {
    bucket       = "ha-platform-prod-terraform-state"
    key          = "terraform/state/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
    encrypt      = true
  }
}
