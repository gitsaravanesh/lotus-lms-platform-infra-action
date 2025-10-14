output "cognito_user_pool_id" {
    value = module.cognito.user_pool_id
}


output "cognito_client_id" {
    value = module.cognito.user_pool_client_id
}


output "cognito_domain" {
    value = module.cognito.cognito_domain
}


output "frontend_bucket_name" {
    value = module.s3_frontend.bucket_name
}


output "dynamodb_table_name" {
    value = module.dynamodb.table_name
}


output "api_invoke_url" {
    value = module.lambda_backend.api_invoke_url
}