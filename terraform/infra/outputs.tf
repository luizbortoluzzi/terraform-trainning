output "cloudfront_url" {
  description = "URL pública do site (use no navegador)."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "ID da distribuição CloudFront — usado pelo CI para invalidar o cache."
  value       = aws_cloudfront_distribution.site.id
}

output "site_bucket_name" {
  description = "Nome do bucket S3 do site — usado pelo CI no `aws s3 sync`."
  value       = aws_s3_bucket.site.id
}

output "github_actions_role_arn" {
  description = "ARN da role assumida pelo GitHub Actions — coloque como secret/variable no repo."
  value       = aws_iam_role.github_actions.arn
}
