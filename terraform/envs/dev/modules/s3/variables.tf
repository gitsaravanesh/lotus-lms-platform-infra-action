variable "bucket_name" {
  description = "The name of the S3 bucket for frontend hosting"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod, etc.)"
  type        = string
}