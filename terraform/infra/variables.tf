variable "aws_region" {
  description = "AWS region where the site bucket will be created (delivery is global via CloudFront)."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name, used in resource names and tags."
  type        = string
  default     = "terraform-trainning"
}

variable "site_bucket_name" {
  description = "Name of the S3 bucket that holds the site files. MUST be globally unique."
  type        = string
  default     = "luizbortoluzzi-terraform-trainning"
}

variable "github_owner" {
  description = "GitHub repository owner (user or organization)."
  type        = string
  default     = "luizbortoluzzi"
}

variable "github_repo" {
  description = "Name of the GitHub repository allowed to deploy via OIDC."
  type        = string
  default     = "terraform-trainning"
}
