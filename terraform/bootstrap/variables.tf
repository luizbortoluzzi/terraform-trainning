variable "aws_region" {
  description = "AWS region where the state bucket and lock table will be created."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used in tags."
  type        = string
  default     = "terraform-trainning"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket that holds the tfstate. MUST be globally unique."
  type        = string
  default     = "luizbortoluzzi-terraform-trainning-tfstate"
}

variable "lock_table_name" {
  description = "Name of the DynamoDB table used for state locking."
  type        = string
  default     = "terraform-trainning-lock"
}
