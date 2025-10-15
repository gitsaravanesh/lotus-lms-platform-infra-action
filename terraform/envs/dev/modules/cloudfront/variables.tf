variable "bucket_name" {
  description = "Name of the S3 bucket hosting the frontend"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name for the CloudFront distribution"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate (must be in us-east-1)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
}