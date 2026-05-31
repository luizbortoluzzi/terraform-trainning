###############################################################################
# SITE S3 BUCKET
#
# The bucket is 100% PRIVATE. Nobody accesses S3 directly from the internet —
# only CloudFront, via OAC (Origin Access Control). This is safer than making
# the bucket public.
###############################################################################

resource "aws_s3_bucket" "site" {
  bucket = var.site_bucket_name
}

# Blocks all public access. Access is granted ONLY to CloudFront, further
# below, via a bucket policy with a SourceArn condition.
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Encryption at rest, at no cost.
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket policy: allows ONLY this CloudFront distribution to read the objects.
# The AWS:SourceArn condition prevents another distribution (or another
# account) from reading them.
data "aws_iam_policy_document" "site_bucket_policy" {
  statement {
    sid       = "AllowCloudFrontRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.site_bucket_policy.json
}
