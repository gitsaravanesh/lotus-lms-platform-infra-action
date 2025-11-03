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