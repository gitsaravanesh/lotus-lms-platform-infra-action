# DynamoDB table for user-tenant mapping
resource "aws_dynamodb_table" "user_tenant_mapping" {
  name         = "lms-user-tenant-mapping"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  # Enable point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = "lms-user-tenant-mapping"
    Environment = var.environment
    Project     = local.name_prefix
  }
}

# IAM policy for get_user_tenant Lambda
resource "aws_iam_role_policy" "lambda_get_user_tenant_policy" {
  name = "lms-infra-get-user-tenant-policy"
  role = aws_iam_role.lambda_exec.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = [
          aws_dynamodb_table.user_tenant_mapping.arn,
          "${aws_dynamodb_table.user_tenant_mapping.arn}/*"
        ]
      }
    ]
  })
}

# Create placeholder zip if it doesn't exist
resource "null_resource" "create_get_user_tenant_placeholder_zip" {
  provisioner "local-exec" {
    command = <<-EOT
      if ! aws s3 ls s3://${aws_s3_bucket.lambda_artifacts.bucket}/lambda/get_user_tenant.zip 2>/dev/null; then
        mkdir -p /tmp/lambda_get_user_tenant_placeholder
        echo 'def lambda_handler(event, context): return {"statusCode": 200, "body": "placeholder"}' > /tmp/lambda_get_user_tenant_placeholder/get_user_tenant.py
        cd /tmp/lambda_get_user_tenant_placeholder && zip -r /tmp/get_user_tenant_placeholder.zip . && cd -
        aws s3 cp /tmp/get_user_tenant_placeholder.zip s3://${aws_s3_bucket.lambda_artifacts.bucket}/lambda/get_user_tenant.zip
        rm -rf /tmp/lambda_get_user_tenant_placeholder /tmp/get_user_tenant_placeholder.zip
      fi
    EOT
  }

  depends_on = [aws_s3_bucket.lambda_artifacts]
}

# Lambda function for get_user_tenant
resource "aws_lambda_function" "get_user_tenant" {
  function_name = "lms-infra-get-user-tenant"
  runtime       = "python3.10"
  handler       = "get_user_tenant.lambda_handler"
  role          = aws_iam_role.lambda_exec.arn

  s3_bucket = aws_s3_bucket.lambda_artifacts.bucket
  s3_key    = "lambda/get_user_tenant.zip"

  memory_size = 256
  timeout     = 10

  environment {
    variables = {
      USER_TENANT_MAPPING_TABLE = aws_dynamodb_table.user_tenant_mapping.name
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_get_user_tenant_policy,
    null_resource.create_get_user_tenant_placeholder_zip
  ]

  lifecycle {
    ignore_changes = [
      source_code_hash
    ]
  }
}

# API Gateway resource: /user
resource "aws_api_gateway_resource" "user" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  parent_id   = aws_api_gateway_rest_api.lms_api.root_resource_id
  path_part   = "user"
}

# API Gateway resource: /user/tenant
resource "aws_api_gateway_resource" "user_tenant" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  parent_id   = aws_api_gateway_resource.user.id
  path_part   = "tenant"
}

# GET method for /user/tenant
resource "aws_api_gateway_method" "get_user_tenant" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = aws_api_gateway_resource.user_tenant.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.querystring.user_id" = false
  }
}

# Lambda integration for GET /user/tenant
resource "aws_api_gateway_integration" "get_user_tenant_integration" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.user_tenant.id
  http_method = aws_api_gateway_method.get_user_tenant.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.get_user_tenant.invoke_arn
  timeout_milliseconds    = 29000
}

# OPTIONS method for CORS on /user/tenant
resource "aws_api_gateway_method" "options_user_tenant" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = aws_api_gateway_resource.user_tenant.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# MOCK integration for OPTIONS /user/tenant
resource "aws_api_gateway_integration" "options_user_tenant_integration" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.user_tenant.id
  http_method = aws_api_gateway_method.options_user_tenant.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

# Method response for OPTIONS /user/tenant
resource "aws_api_gateway_method_response" "options_user_tenant_200" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.user_tenant.id
  http_method = aws_api_gateway_method.options_user_tenant.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

# Integration response for OPTIONS /user/tenant
resource "aws_api_gateway_integration_response" "options_user_tenant_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.user_tenant.id
  http_method = aws_api_gateway_method.options_user_tenant.http_method
  status_code = aws_api_gateway_method_response.options_user_tenant_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Tenant-Id,Authorization'"
  }

  depends_on = [
    aws_api_gateway_integration.options_user_tenant_integration
  ]
}

# Lambda permission for API Gateway to invoke get_user_tenant
resource "aws_lambda_permission" "allow_api_gateway_get_user_tenant" {
  statement_id  = "AllowAPIGatewayInvokeGetUserTenant"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_user_tenant.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lms_api.execution_arn}/*/*"
}
