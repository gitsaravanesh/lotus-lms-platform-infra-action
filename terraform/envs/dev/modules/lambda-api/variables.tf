variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project_prefix" {
  type    = string
  default = "lms"
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

variable "stage_name" {
  type    = string
  default = "dev"
}