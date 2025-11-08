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

variable "region" {
  description = "AWS region where the S3 bucket exists"
  type        = string
  default     = "ap-south-1"
}

variable "project_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "lotus-lms"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "backend_principals" {
  description = "List of IAM service principals that can assume the backend role"
  type        = list(string)
  default     = ["ec2.amazonaws.com", "ecs-tasks.amazonaws.com", "lambda.amazonaws.com"]
}