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

output "list_videos_endpoint" {
  description = "API Gateway endpoint for list videos"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/courses/{course_id}/videos"
}

output "users_table_name" {
  description = "Name of the DynamoDB table for user data"
  value       = aws_dynamodb_table.users.name
}

output "users_table_arn" {
  description = "ARN of the DynamoDB table for user data"
  value       = aws_dynamodb_table.users.arn
}

output "user_tenant_mapping_table_name" {
  description = "Name of the DynamoDB table for user-tenant mapping"
  value       = aws_dynamodb_table.user_tenant_mapping.name
}

output "user_tenant_mapping_table_arn" {
  description = "ARN of the DynamoDB table for user-tenant mapping"
  value       = aws_dynamodb_table.user_tenant_mapping.arn
}

output "get_user_tenant_endpoint" {
  description = "API Gateway endpoint for get user tenant mapping"
  value       = "${aws_api_gateway_stage.dev.invoke_url}/user/tenant"
}

output "cognito_post_confirmation_lambda_arn" {
  description = "ARN of the Cognito Post Confirmation Lambda function"
  value       = aws_lambda_function.cognito_post_confirmation.arn
}