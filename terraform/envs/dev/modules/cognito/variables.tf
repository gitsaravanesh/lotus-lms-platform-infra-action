variable "user_pool_name" {
  type = string
}


variable "cognito_domain_prefix" {
  type = string
}


variable "callback_urls" {
  type = list(string)
}


variable "logout_urls" {
  type = list(string)
}


variable "google_client_id" {
  type      = string
  sensitive = true
}


variable "google_client_secret" {
  type      = string
  sensitive = true
}


variable "enabled_identity_providers" {
  type    = list(string)
  default = ["Google"]
}

variable "post_confirmation_lambda_arn" {
  type        = string
  description = "ARN of Lambda function to trigger post user confirmation"
  default     = ""
}

variable "project_name" {
  type = string
  default = "lms"
}