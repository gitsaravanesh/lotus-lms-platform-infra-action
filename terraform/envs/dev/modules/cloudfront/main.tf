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
    domain_name = "${var.bucket_name}.s3-website-${var.region}.amazonaws.com"
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
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
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