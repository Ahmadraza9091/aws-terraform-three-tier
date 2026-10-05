terraform {
  backend "s3" {
    bucket       = "terraform-statefile-ahmad-01102026"
    key          = "production-style-aws-infrastructure/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}