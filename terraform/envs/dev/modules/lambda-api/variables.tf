variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_prefix" {
  type    = string
  default = "lotus-lms"
}

variable "lambda_runtime" {
  type    = string
  default = "python3.10"
}

variable "lambda_handler" {
  type    = string
  default = "handler.lambda_handler"
}

variable "lambda_timeout" {
  type    = number
  default = 15
}

variable "lambda_memory" {
  type    = number
  default = 256
}

variable "courses_table_name" {
  type    = string
  default = "lms-courses"
}

variable "transactions_table_name" {
  type    = string
  default = "lms-transactions"
}


variable "stage_name" {
  type    = string
  default = "dev"
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