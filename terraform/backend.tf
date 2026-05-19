terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket-12345"
    key            = "prod/terraform.tfstate"
    region         = "us-west-2"
    use_lockfile   = true
    encrypt        = true
  }
}