###############################################################################
# BOOTSTRAP
#
# Creates the infrastructure that STORES the Terraform state:
#   - 1 S3 bucket (holds the terraform.tfstate file, versioned and encrypted)
#   - 1 DynamoDB table (the "lock" so two applies can't run at the same time)
#
# This module uses LOCAL state (terraform.tfstate right here in this folder),
# because the remote backend does not exist yet at the moment we run this. It's
# the classic chicken-and-egg problem. Runs once and rarely changes.
###############################################################################

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Tags applied to every resource created by this provider — great for
  # tracking costs and knowing what belongs to the project.
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Module    = "bootstrap"
    }
  }
}

# ---------------------------------------------------------------------------
# S3 bucket that holds the Terraform state
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "tfstate" {
  bucket = var.state_bucket_name

  # Protects against `terraform destroy` accidentally wiping the state bucket.
  lifecycle {
    prevent_destroy = true
  }
}

# Versioning: keeps a history of the state. If an apply corrupts something,
# you can roll back to a previous version.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption at rest (SSE-S3 / AES256), at no extra cost.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Blocks ANY public access to the state bucket.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket                  = aws_s3_bucket.tfstate.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# DynamoDB table for state locking
# ---------------------------------------------------------------------------
# PAY_PER_REQUEST = billed per use. Since the lock is only used during
# apply/plan, usage is minimal and stays within the free tier.
resource "aws_dynamodb_table" "tflock" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
