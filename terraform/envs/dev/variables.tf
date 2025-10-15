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