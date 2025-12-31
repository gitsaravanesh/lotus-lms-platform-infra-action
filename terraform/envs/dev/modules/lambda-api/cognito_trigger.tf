# IAM policy for Cognito Post Confirmation Lambda to write to DynamoDB tables
resource "aws_iam_role_policy" "lambda_cognito_post_confirmation_policy" {
  name = "lms-infra-cognito-post-confirmation-policy"
  role = aws_iam_role.lambda_exec.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem"
        ]
        Resource = [
          aws_dynamodb_table.users.arn,
          aws_dynamodb_table.user_tenant_mapping.arn
        ]
      }
    ]
  })
}

# Create placeholder zip if it doesn't exist
resource "null_resource" "create_cognito_post_confirmation_placeholder_zip" {
  provisioner "local-exec" {
    command = <<-EOT
      if ! aws s3 ls s3://${aws_s3_bucket.lambda_artifacts.bucket}/lambda/cognito_post_confirmation.zip 2>/dev/null; then
        mkdir -p /tmp/lambda_cognito_post_confirmation_placeholder
        echo 'def lambda_handler(event, context): return event' > /tmp/lambda_cognito_post_confirmation_placeholder/cognito_post_confirmation.py
        cd /tmp/lambda_cognito_post_confirmation_placeholder && zip -r /tmp/cognito_post_confirmation_placeholder.zip . && cd -
        aws s3 cp /tmp/cognito_post_confirmation_placeholder.zip s3://${aws_s3_bucket.lambda_artifacts.bucket}/lambda/cognito_post_confirmation.zip
        rm -rf /tmp/lambda_cognito_post_confirmation_placeholder /tmp/cognito_post_confirmation_placeholder.zip
      fi
    EOT
  }

  depends_on = [aws_s3_bucket.lambda_artifacts]
}

# Lambda function for Cognito Post Confirmation trigger
resource "aws_lambda_function" "cognito_post_confirmation" {
  function_name = "lms-infra-cognito-post-confirmation"
  runtime       = "python3.10"
  handler       = "cognito_post_confirmation.lambda_handler"
  role          = aws_iam_role.lambda_exec.arn

  s3_bucket = aws_s3_bucket.lambda_artifacts.bucket
  s3_key    = "lambda/cognito_post_confirmation.zip"

  memory_size = 256
  timeout     = 10

  environment {
    variables = {
      USERS_TABLE                = aws_dynamodb_table.users.name
      USER_TENANT_MAPPING_TABLE  = aws_dynamodb_table.user_tenant_mapping.name
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_cognito_post_confirmation_policy,
    null_resource.create_cognito_post_confirmation_placeholder_zip
  ]

  lifecycle {
    ignore_changes = [
      source_code_hash
    ]
  }
}

# Lambda permission to allow Cognito to invoke the function
resource "aws_lambda_permission" "allow_cognito_invoke_post_confirmation" {
  statement_id  = "AllowCognitoInvokePostConfirmation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cognito_post_confirmation.function_name
  principal     = "cognito-idp.amazonaws.com"
}
