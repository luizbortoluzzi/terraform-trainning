###############################################################################
# CLOUDFRONT (CDN + HTTPS)
#
# Distributes the site globally, with free HTTPS on the *.cloudfront.net domain.
# Uses OAC to access the private S3 bucket in an authenticated way.
###############################################################################

# OAC = Origin Access Control. The modern way (replaces the old OAI) for
# CloudFront to access a private S3 bucket, signing requests with SigV4.
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC for the site bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Function (runs at the edge) that rewrites the URL:
#   /            -> /index.html  (already covered by default_root_object, but be safe)
#   /about/      -> /about/index.html
# Needed because Next with trailingSlash generates index.html inside folders,
# and the S3 (REST) origin does not resolve a "directory index" on its own.
resource "aws_cloudfront_function" "rewrite_index" {
  name    = "${var.project_name}-rewrite-index"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrites directory URLs to /index.html"
  publish = true
  code    = <<-EOT
    function handler(event) {
      var request = event.request;
      var uri = request.uri;
      if (uri.endsWith('/')) {
        request.uri += 'index.html';
      } else if (!uri.includes('.')) {
        request.uri += '/index.html';
      }
      return request;
    }
  EOT

  # When the function is recreated (e.g. on a name change), create the new one
  # BEFORE deleting the old. Without this, CloudFront refuses to delete a
  # function still associated with the distribution (FunctionInUse error).
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "${var.project_name} - static site"

  # PriceClass_100 = only the cheapest edges (US, Canada, Europe). Lowers cost
  # and still serves the whole world (with slightly higher latency outside
  # those regions). Switch to PriceClass_All for all edges.
  price_class = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${aws_s3_bucket.site.id}"
    viewer_protocol_policy = "redirect-to-https" # force HTTPS
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # AWS-managed "CachingOptimized" cache policy (fixed global ID).
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite_index.arn
    }
  }

  # SPA/404: if the object does not exist, return Next's 404 page.
  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }
  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Default CloudFront HTTPS certificate (*.cloudfront.net), free.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
