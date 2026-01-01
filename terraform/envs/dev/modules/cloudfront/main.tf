######################################
# CloudFront Distribution
######################################

data "aws_s3_bucket" "frontend" {
  bucket = var.bucket_name
}

resource "aws_cloudfront_distribution" "frontend" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for ${var.bucket_name}"
  default_root_object = "index.html"

  origin {
    domain_name = "${var.bucket_name}.s3.${var.region}.amazonaws.com"
    origin_id   = "s3-static-site-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # static website endpoint only supports HTTP
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-static-site-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]  # Added OPTIONS for CORS preflight
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true  # Changed from false - required for OAuth redirects
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400      # 24 hours
    max_ttl     = 31536000   # 1 year
  }

  # Handle 403 Forbidden errors - return index.html for client-side routing
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  # Handle 404 Not Found errors - return index.html for client-side routing
  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  price_class = "PriceClass_100"

  viewer_certificate {
    cloudfront_default_certificate = true # ✅ AWS-managed HTTPS cert
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name        = "lms-cloudfront-${var.environment}"
    Environment = var.environment
  }
}