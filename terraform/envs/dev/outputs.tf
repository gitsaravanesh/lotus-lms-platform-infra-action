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

output "list_videos_endpoint" {
  description = "List videos API endpoint"
  value       = module.lambda.list_videos_endpoint
}

output "users_table_name" {
  description = "Name of the users DynamoDB table"
  value       = module.lambda.users_table_name
}

# CloudFront outputs for frontend deployment
# These outputs should be used in GitHub Actions secrets for the frontend deployment workflow
# Example: terraform output cloudfront_distribution_id
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidation"
  value       = module.cloudfront.cloudfront_distribution_id
}

output "cloudfront_distribution_domain" {
  description = "CloudFront domain name (public HTTPS URL)"
  value       = module.cloudfront.cloudfront_distribution_domain
}