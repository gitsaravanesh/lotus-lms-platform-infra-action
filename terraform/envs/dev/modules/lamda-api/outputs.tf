output "api_endpoint" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}

output "lambda_function_name" {
  value = aws_lambda_function.list_courses.function_name
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.courses.name
}