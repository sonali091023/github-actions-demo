terraform {
  backend "s3" {
    bucket         = "skill-pulse-dev-tf-state"
    key            = "dev/terraform.tfstate"
    region         = "us-west-2"
    #dynamodb_table = "skill-pulse-dev-tf-lock"
    use_lockfile   = true
    encrypt        = true
  }
}