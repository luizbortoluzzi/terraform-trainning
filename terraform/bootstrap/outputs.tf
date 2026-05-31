output "state_bucket_name" {
  description = "Nome do bucket S3 de estado. Use este valor no backend.tf da infra."
  value       = aws_s3_bucket.tfstate.id
}

output "lock_table_name" {
  description = "Nome da tabela DynamoDB de lock. Use no backend.tf da infra."
  value       = aws_dynamodb_table.tflock.name
}

output "aws_region" {
  description = "Região usada no bootstrap."
  value       = var.aws_region
}
