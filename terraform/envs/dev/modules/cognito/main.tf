##########################################
# Cognito User Pool
##########################################

resource "aws_cognito_user_pool" "this" {
  name = var.user_pool_name

  auto_verified_attributes = ["email"]
  alias_attributes         = ["email"]

  ##########################################
  # Email Verification (Link)
  ##########################################
  verification_message_template {
    default_email_option  = "CONFIRM_WITH_LINK"
    email_subject         = "Verify your Lotus LMS account"
    email_message_by_link = "Hi,<br><br>Click the link below to verify your account:<br><br>{##Verify Email##}<br><br>Thanks,<br>Lotus LMS Team"
  }

  ##########################################
  # Password Policy
  ##########################################
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = false
    require_numbers   = false
    require_symbols   = false
  }

  ##########################################
  # Allow self sign-up
  ##########################################
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  mfa_configuration = "OFF"

  ##########################################
  # Schema
  ##########################################

  # Email (standard)
  schema {
    name                = "email"
    attribute_data_type = "String"
    mutable             = true
    required            = true

    string_attribute_constraints {
      min_length = "3"
      max_length = "255"
    }
  }

  # Custom: interest
  schema {
    name                = "interest"
    attribute_data_type = "String"
    mutable             = true
    required            = false

    string_attribute_constraints {
      min_length = "1"
      max_length = "100"
    }
  }

  # ✅ Custom: student_username (SAFE)
  schema {
    name                = "student_username"
    attribute_data_type = "String"
    mutable             = true
    required            = false

    string_attribute_constraints {
      min_length = "3"
      max_length = "50"
    }
  }

  ##########################################
  # Email Configuration
  ##########################################
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  ##########################################
  # Lambda Triggers (optional)
  ##########################################
  dynamic "lambda_config" {
    for_each = var.post_confirmation_lambda_arn != "" ? [1] : []
    content {
      post_confirmation = var.post_confirmation_lambda_arn
    }
  }
}

##########################################
# Cognito Domain
##########################################

resource "aws_cognito_user_pool_domain" "this" {
  domain       = var.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.this.id
}

##########################################
# Identity Provider - Google
##########################################

resource "aws_cognito_identity_provider" "google" {
  provider_name = "Google"
  provider_type = "Google"
  user_pool_id  = aws_cognito_user_pool.this.id

  attribute_mapping = {
    email                      = "email"
    username                   = "sub"
    name                       = "name"
    given_name                 = "given_name"
    family_name                = "family_name"
    "custom:student_username"  = "email"
  }

  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "openid email profile"
  }
}

##########################################
# Cognito User Pool App Client
##########################################

resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.user_pool_name}-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = false

  supported_identity_providers = [
    "COGNITO",
    "Google"
  ]

  ##########################################
  # OAuth Configuration
  ##########################################
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  ##########################################
  # Explicit Auth Flows
  ##########################################
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"

  refresh_token_validity = 30

  ##########################################
  # Attribute Permissions (CRITICAL)
  ##########################################
  read_attributes = [
    "email",

    # Required for profile scope
    "name",
    "given_name",
    "family_name",
    "preferred_username",
    "picture",

    "custom:interest",
    "custom:student_username"
  ]

  write_attributes = [
    "email",
    "custom:interest",
    "custom:student_username"
  ]

  ##########################################
  # Safety
  ##########################################
  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_cognito_identity_provider.google
  ]
}