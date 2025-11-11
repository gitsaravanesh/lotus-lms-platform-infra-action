output "api_endpoint" {
  description = "Base URL of the deployed REST API"
  value       = "https://${aws_api_gateway_rest_api.lms_api.id}.execute-api.${var.aws_region}.amazonaws.com/prod"
}

output "lambda_function_name" {
  value = aws_lambda_function.list_courses.function_name
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.courses.name
}

output "videos_bucket_name" {
  description = "Name of the S3 bucket for video storage"
  value       = aws_s3_bucket.videos_bucket.id
}

output "videos_table_name" {
  description = "Name of the DynamoDB table for video metadata"
  value       = aws_dynamodb_table.videos_table.name
}

output "backend_role_arn" {
  description = "ARN of the backend IAM role"
  value       = aws_iam_role.backend_role.arn
}