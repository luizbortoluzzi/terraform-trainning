###############################################################################
# BUCKET S3 DO SITE
#
# O bucket é 100% PRIVADO. Ninguém acessa o S3 direto pela internet — só o
# CloudFront, via OAC (Origin Access Control). Isso é mais seguro do que
# deixar o bucket público.
###############################################################################

resource "aws_s3_bucket" "site" {
  bucket = var.site_bucket_name
}

# Bloqueia todo acesso público. O acesso é liberado SÓ pro CloudFront, mais
# abaixo, via bucket policy com condição de SourceArn.
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Criptografia em repouso, sem custo.
resource "aws_s3_bucket_server_side_encryption_configuration" "site" {
  bucket = aws_s3_bucket.site.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Política do bucket: permite que SOMENTE esta distribuição do CloudFront
# leia os objetos. A condição AWS:SourceArn impede que outra distribuição
# (ou outra conta) consiga ler.
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
