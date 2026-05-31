output "cloudfront_url" {
  description = "Public URL of the site (open in the browser)."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — used by the CI to invalidate the cache."
  value       = aws_cloudfront_distribution.site.id
}

output "site_bucket_name" {
  description = "Name of the site's S3 bucket — used by the CI in `aws s3 sync`."
  value       = aws_s3_bucket.site.id
}

output "github_actions_role_arn" {
  description = "ARN of the role assumed by GitHub Actions — set it as a repo secret/variable."
  value       = aws_iam_role.github_actions.arn
}
