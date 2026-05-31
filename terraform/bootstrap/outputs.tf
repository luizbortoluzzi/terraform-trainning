output "state_bucket_name" {
  description = "Name of the S3 state bucket. Use this value in the infra's backend.tf."
  value       = aws_s3_bucket.tfstate.id
}

output "lock_table_name" {
  description = "Name of the DynamoDB lock table. Use it in the infra's backend.tf."
  value       = aws_dynamodb_table.tflock.name
}

output "aws_region" {
  description = "Region used by the bootstrap."
  value       = var.aws_region
}
