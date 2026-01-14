############################################
# Cognito User Pool (SINGLE SOURCE OF TRUTH)
############################################
resource "aws_cognito_user_pool" "this" {
  name = "${var.project_name}-user-pool"

  auto_verified_attributes = ["email"]

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = false
  }
  
  schema {
    name                = "custom:student_username"
    attribute_data_type = "String"
    required            = false
    mutable             = true
  }
}

############################################
# Cognito Domain (Hosted UI)
############################################
resource "aws_cognito_user_pool_domain" "this" {
  domain       = "${var.project_name}-auth"
  user_pool_id = aws_cognito_user_pool.this.id
}

############################################
# Direct Auth App Client (Username/Password)
############################################
resource "aws_cognito_user_pool_client" "direct_auth" {
  name         = "${var.project_name}-direct-auth"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"
}

############################################
# Google Identity Provider
############################################
resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.this.id
  provider_name = "Google"
  provider_type = "Google"

  provider_details = {
    client_id         = var.google_client_id
    client_secret     = var.google_client_secret
    authorize_scopes  = "openid email profile"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
  }
}

############################################
# OAuth / Hosted UI App Client
############################################
resource "aws_cognito_user_pool_client" "oauth" {
  name         = "${var.project_name}-oauth"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  allowed_oauth_flows = ["code"]
  allowed_oauth_scopes = [
    "openid",
    "email",
    "profile"
  ]
  allowed_oauth_flows_user_pool_client = true

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  supported_identity_providers = [
    "COGNITO",
    aws_cognito_identity_provider.google.provider_name
  ]

  # CRITICAL: Google must exist before OAuth client
  depends_on = [
    aws_cognito_identity_provider.google
  ]
}