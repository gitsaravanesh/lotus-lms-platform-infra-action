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
  value = module.s3.bucket_name
}

output "frontend_website_url" {
  value = module.s3.website_endpoint
}

output "videos_bucket_name" {
  value = module.lambda.videos_bucket_name
}

output "videos_table_name" {
  value = module.lambda.videos_table_name
}