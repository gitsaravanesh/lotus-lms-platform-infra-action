# IAM policy for update_transaction Lambda
resource "aws_iam_role_policy" "lambda_update_transaction_policy" {
  name = "lms-infra-update-transaction-policy"
  role = aws_iam_role.lambda_exec.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem"
        ]
        Effect = "Allow"
        Resource = [
          aws_dynamodb_table.transactions.arn,
          "${aws_dynamodb_table.transactions.arn}/*"
        ]
      }
    ]
  })
}

# Create placeholder zip if it doesn't exist
resource "null_resource" "create_update_transaction_placeholder_zip" {
  provisioner "local-exec" {
    command = <<-EOT
      if ! aws s3 ls s3://${aws_s3_bucket.lambda_artifacts.bucket}/lambda/update_transaction.zip 2>/dev/null; then
        mkdir -p /tmp/lambda_update_transaction_placeholder
        echo 'def handler(event, context): return {"statusCode": 200, "body": "placeholder"}' > /tmp/lambda_update_transaction_placeholder/handler.py
        cd /tmp/lambda_update_transaction_placeholder && zip -r /tmp/update_transaction_placeholder.zip . && cd -
        aws s3 cp /tmp/update_transaction_placeholder.zip s3://${aws_s3_bucket.lambda_artifacts.bucket}/lambda/update_transaction.zip
        rm -rf /tmp/lambda_update_transaction_placeholder /tmp/update_transaction_placeholder.zip
      fi
    EOT
  }

  depends_on = [aws_s3_bucket.lambda_artifacts]
}

# Lambda function for update_transaction
resource "aws_lambda_function" "update_transaction" {
  function_name = "lms-infra-update-transaction"
  runtime       = "python3.10"
  handler       = "update_transaction.handler"
  role          = aws_iam_role.lambda_exec.arn

  s3_bucket = aws_s3_bucket.lambda_artifacts.bucket
  s3_key    = "lambda/update_transaction.zip"

  memory_size = 256
  timeout     = 10

  environment {
    variables = {
      TRANSACTIONS_TABLE = aws_dynamodb_table.transactions.name
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_update_transaction_policy,
    null_resource.create_update_transaction_placeholder_zip
  ]

  lifecycle {
    ignore_changes = [
      # Ignore changes to source code hash since we update via GitHub Actions
      source_code_hash
    ]
  }
}

# API Gateway resource: /transactions
resource "aws_api_gateway_resource" "transactions" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  parent_id   = aws_api_gateway_rest_api.lms_api.root_resource_id
  path_part   = "transactions"
}

# API Gateway resource: /transactions/{transaction_id}
resource "aws_api_gateway_resource" "transaction_by_id" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  parent_id   = aws_api_gateway_resource.transactions.id
  path_part   = "{transaction_id}"
}

# PUT method for updating transaction
resource "aws_api_gateway_method" "put_transaction" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = aws_api_gateway_resource.transaction_by_id.id
  http_method   = "PUT"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.transaction_id" = true
  }
}

resource "aws_api_gateway_integration" "put_transaction_integration" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.transaction_by_id.id
  http_method = aws_api_gateway_method.put_transaction.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.update_transaction.invoke_arn
  timeout_milliseconds    = 29000
}

# OPTIONS method for CORS
resource "aws_api_gateway_method" "options_transaction_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = aws_api_gateway_resource.transaction_by_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_transaction_by_id_integration" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.transaction_by_id.id
  http_method = aws_api_gateway_method.options_transaction_by_id.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_transaction_by_id_200" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.transaction_by_id.id
  http_method = aws_api_gateway_method.options_transaction_by_id.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

resource "aws_api_gateway_integration_response" "options_transaction_by_id_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.transaction_by_id.id
  http_method = aws_api_gateway_method.options_transaction_by_id.http_method
  status_code = aws_api_gateway_method_response.options_transaction_by_id_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'PUT,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Tenant-Id,Authorization'"
  }

  depends_on = [
    aws_api_gateway_integration.options_transaction_by_id_integration
  ]
}

# Lambda permission
resource "aws_lambda_permission" "allow_api_gateway_update_transaction" {
  statement_id  = "AllowAPIGatewayInvokeUpdateTransaction"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.update_transaction.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lms_api.execution_arn}/*/*"
}
