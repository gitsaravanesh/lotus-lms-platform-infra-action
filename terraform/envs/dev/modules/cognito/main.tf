resource "aws_cognito_identity_provider" "google" {
  count = length(var.enabled_identity_providers) > 0 && contains(var.enabled_identity_providers, "Google") ? 1 : 0
  provider_name = "Google"
  provider_type = "Google"
  user_pool_id = aws_cognito_user_pool.this.id

  attribute_mapping = {
    email    = "email"
    username = "sub"
    name     = "name"
  }

  provider_details = {
    client_id       = var.google_client_id
    client_secret   = var.google_client_secret
    authorize_scopes = "openid email profile"
  }
}

resource "null_resource" "wait_for_idp" {
  count      = aws_cognito_identity_provider.google[0] != null ? 1 : 0
  depends_on = [aws_cognito_identity_provider.google]
  provisioner "local-exec" {
    command = "sleep 10"
  }
}

resource "aws_cognito_user_pool_client" "this" {
  name                             = "${var.user_pool_name}-client"
  user_pool_id                     = aws_cognito_user_pool.this.id
  explicit_auth_flows              = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  prevent_user_existence_errors    = "ENABLED"
  generate_secret                  = false
  supported_identity_providers     = ["Google"]
  allowed_oauth_flows              = ["code"]
  allowed_oauth_scopes             = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true
  callback_urls                    = var.callback_urls
  logout_urls                      = var.logout_urls
  refresh_token_validity           = 30

  depends_on = [null_resource.wait_for_idp]
}