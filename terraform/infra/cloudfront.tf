###############################################################################
# CLOUDFRONT (CDN + HTTPS)
#
# Distribui o site globalmente, com HTTPS grátis no domínio *.cloudfront.net.
# Usa OAC para acessar o bucket S3 privado de forma autenticada.
###############################################################################

# OAC = Origin Access Control. É a forma moderna (substitui o antigo OAI) de o
# CloudFront acessar um bucket S3 privado assinando as requisições com SigV4.
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-oac"
  description                       = "OAC para o bucket do site"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# Função CloudFront (roda na borda) que reescreve a URL:
#   /            -> /index.html  (já coberto por default_root_object, mas garante)
#   /sobre/      -> /sobre/index.html
# Necessário porque o Next com trailingSlash gera index.html dentro de pastas,
# e o origin S3 (REST) não resolve "index de diretório" sozinho.
resource "aws_cloudfront_function" "rewrite_index" {
  name    = "${var.project_name}-rewrite-index"
  runtime = "cloudfront-js-2.0"
  comment = "Reescreve URLs de diretório para /index.html"
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

  # Quando a função for recriada (ex.: ao mudar o nome), cria a nova ANTES de
  # apagar a antiga. Sem isso, o CloudFront recusa apagar uma função que ainda
  # está associada à distribuição (erro FunctionInUse).
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"
  comment             = "${var.project_name} - site estático"

  # PriceClass_100 = só edges mais baratas (EUA, Canadá, Europa). Reduz custo
  # e continua atendendo o mundo todo (com latência um pouco maior fora dessas
  # regiões). Troque para PriceClass_All se quiser todas as edges.
  price_class = "PriceClass_100"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3-${aws_s3_bucket.site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-${aws_s3_bucket.site.id}"
    viewer_protocol_policy = "redirect-to-https" # força HTTPS
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # Política de cache gerenciada pela AWS "CachingOptimized" (ID fixo global).
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite_index.arn
    }
  }

  # SPA/404: se o objeto não existir, devolve a página 404 do Next.
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

  # Certificado HTTPS padrão do CloudFront (*.cloudfront.net), grátis.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}
