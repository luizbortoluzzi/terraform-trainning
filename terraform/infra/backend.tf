###############################################################################
# REMOTE BACKEND
#
# Tells Terraform to store the state in the S3 bucket created by the bootstrap,
# with locking via DynamoDB. NOTE: the values here do NOT accept variables
# (a Terraform limitation), so they must match exactly what the bootstrap
# created.
###############################################################################

terraform {
  backend "s3" {
    bucket         = "luizbortoluzzi-terraform-trainning-tfstate"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-trainning-lock"
    encrypt        = true
  }
}
