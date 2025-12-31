##########################################
# Cognito User Pool
##########################################

resource "aws_cognito_user_pool" "this" {
  name = var.user_pool_name

  # Verify email but require username
  auto_verified_attributes = ["email"]
  # Remove username_attributes to make username mandatory
  # username_attributes      = ["email"]  

  ##########################################
  # ✅ Use Email Link Verification (instead of OTP)
  ##########################################
  verification_message_template {
    default_email_option  = "CONFIRM_WITH_LINK"
    email_subject         = "Verify your Lotus LMS account"
    email_message_by_link = "Hi,<br><br>Click the link below to verify your account:<br><br>{##Verify Email##}<br><br>Thanks,<br>Lotus LMS Team"
  }

  # Add alias attributes to allow login with either username or email
  alias_attributes = ["email"]

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
  # Allow users to self-register
  ##########################################
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  mfa_configuration = "OFF"

  ##########################################
  # Schema Configuration
  ##########################################
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = true # Make email required
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = "3"
      max_length = "255"
    }
  }

  schema {
    name                     = "interest"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = "1"
      max_length = "100"
    }
  }

  schema {
    name                     = "username"
    attribute_data_type      = "String"
    mutable                  = true
    required                 = false
    developer_only_attribute = false

    string_attribute_constraints {
      min_length = "3"
      max_length = "50"
    }
  }

  ##########################################
  # 📧 Email Configuration (using Cognito’s default email service)
  ##########################################
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  ##########################################
  # Lambda Triggers
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
# Identity Provider (Google)
##########################################

resource "aws_cognito_identity_provider" "google" {
  count         = length(var.enabled_identity_providers) > 0 && contains(var.enabled_identity_providers, "Google") ? 1 : 0
  provider_name = "Google"
  provider_type = "Google"
  user_pool_id  = aws_cognito_user_pool.this.id

  attribute_mapping = {
    email             = "email"
    username          = "sub"
    name              = "name"
    "custom:username" = "email"
  }

  provider_details = {
    client_id        = var.google_client_id
    client_secret    = var.google_client_secret
    authorize_scopes = "openid email profile"
  }
}

##########################################
# Wait for IDP Setup
##########################################

resource "null_resource" "wait_for_idp" {
  count      = aws_cognito_identity_provider.google[0] != null ? 1 : 0
  depends_on = [aws_cognito_identity_provider.google]

  provisioner "local-exec" {
    command = "sleep 10"
  }
}

##########################################
# Cognito User Pool App Client
##########################################

resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.user_pool_name}-client"
  user_pool_id = aws_cognito_user_pool.this.id

  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  prevent_user_existence_errors = "ENABLED"
  generate_secret               = false
  supported_identity_providers  = ["COGNITO", "Google"]

  ##########################################
  # ✅ Keep "code" flow for OAuth 2.0
  ##########################################
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = var.callback_urls
  logout_urls   = var.logout_urls

  refresh_token_validity = 30

  ##########################################
  # 🧠 Enable Read/Write Access to Custom Attribute
  ##########################################
  read_attributes = [
    "email",
    "custom:interest",
    "custom:username"
  ]

  write_attributes = [
    "email",
    "custom:interest",
    "custom:username"
  ]

  depends_on = [null_resource.wait_for_idp]
}