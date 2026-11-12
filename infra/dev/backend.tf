terraform {
  backend "s3" {
    bucket       = "quotemail-tfstate-905418429000"
    key          = "quotemail/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}