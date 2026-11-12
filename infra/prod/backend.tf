terraform {
  backend "s3" {
    bucket       = "quotes-mailsender-tfstate-905418429000"
    key          = "quotes-mailsender/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}