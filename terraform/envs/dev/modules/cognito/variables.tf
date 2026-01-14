variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "project_name" {
  type        = string
  description = "Project name prefix"
}

variable "callback_urls" {
  type        = list(string)
  description = "OAuth callback URLs"
}

variable "logout_urls" {
  type        = list(string)
  description = "OAuth logout URLs"
}

variable "google_client_id" {
  type        = string
}

variable "google_client_secret" {
  type        = string
}