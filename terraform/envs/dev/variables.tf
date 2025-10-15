variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

# Cognito / Google details — provide via terraform.tfvars or CI secrets
variable "google_client_id" {
type = string
sensitive = true
}

variable "google_client_secret" {
type = string
sensitive = true
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
  default     = "dev"
}

variable "acm_certificate_arn" {
  description = "ARN of ACM certificate (must be in us-east-1)"
  type        = string
}