variable "bucket_name" {
  description = "Existing S3 bucket name with static website hosting enabled"
  type        = string
}

variable "region" {
  description = "AWS region where the S3 bucket exists"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}