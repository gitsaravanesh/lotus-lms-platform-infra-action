output "user_pool_id" {
  value = aws_cognito_user_pool.main.id
}

output "direct_client_id" {
  value = aws_cognito_user_pool_client.direct_auth.id
}

output "oauth_client_id" {
  value = aws_cognito_user_pool_client.oauth.id
}

output "cognito_domain" {
  value = aws_cognito_user_pool_domain.main.domain
}