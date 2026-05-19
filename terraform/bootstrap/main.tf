provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "${var.project_name}-${var.env}-tf-state"

  #lifecycle {
    #prevent_destroy = true
  #}

  tags = merge({
  Name        = "${var.project_name}-${var.env}-tf-state"
  Environment = var.env
  Project     = var.project_name
}, var.extra_tags)
}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block Public Access
resource "aws_s3_bucket_public_access_block" "block" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_lock" {
  name         = "${var.project_name}-${var.env}-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = merge({
  Name        = "${var.project_name}-${var.env}-tf-lock"
  Environment = var.env 
  Project     = var.project_name
}, var.extra_tags)
}
