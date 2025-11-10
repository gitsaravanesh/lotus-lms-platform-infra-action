terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

locals {
  name_prefix = "lms-infra"
  env         = "dev"
}

#############################################
# S3 BUCKET FOR LAMBDA CODE ARTIFACTS
#############################################
resource "aws_s3_bucket" "lambda_artifacts" {
  bucket        = "${local.name_prefix}-lambda-artifacts"
  force_destroy = true

  tags = {
    Project = local.name_prefix
    Purpose = "LambdaCodeArtifacts"
  }
}

resource "aws_s3_bucket_versioning" "lambda_artifacts_versioning" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "lambda_artifacts_access" {
  bucket = aws_s3_bucket.lambda_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#############################################
# DYNAMODB TABLE
#############################################
resource "aws_dynamodb_table" "courses" {
  name         = var.courses_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tenant_id"
  range_key    = "course_id"

  attribute {
    name = "tenant_id"
    type = "S"
  }

  attribute {
    name = "course_id"
    type = "S"
  }

  tags = {
    Project = local.name_prefix
  }
}

#############################################
# IAM ROLE FOR LAMBDA
#############################################
data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.courses.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "${aws_s3_bucket.lambda_artifacts.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:ap-south-1:944308403252:key/c1a60caa-ae0d-420d-9fd4-3ee2ece0bbc3"
      }      
    ]
  })
}

#############################################
# LAMBDA FUNCTIONS
#############################################
resource "aws_lambda_function" "list_courses" {
  function_name = "${local.name_prefix}-list-courses"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = var.lambda_runtime
  handler       = var.lambda_handler
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  s3_bucket = aws_s3_bucket.lambda_artifacts.bucket
  s3_key    = "lambda/list_courses.zip"

  environment {
    variables = {
      COURSES_TABLE = aws_dynamodb_table.courses.name
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_s3_bucket.lambda_artifacts
  ]
}

resource "aws_lambda_function" "create_order" {
  function_name = "${local.name_prefix}-create-order"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = var.lambda_runtime
  handler       = "lambda_create_order.lambda_handler"
  timeout       = var.lambda_timeout
  memory_size   = var.lambda_memory

  s3_bucket = aws_s3_bucket.lambda_artifacts.bucket
  s3_key    = "lambda/create_order.zip"

  environment {
    variables = {
      COURSES_TABLE       = aws_dynamodb_table.courses.name
      RAZORPAY_KEY_ID     = "rzp_test_RbvMQRpHT3gMcN"
      RAZORPAY_KEY_SECRET = "UGyRBwnth5tIMPTsWeQ4wNFO"
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_s3_bucket.lambda_artifacts
  ]
}

#############################################
# API GATEWAY REST API
#############################################
resource "aws_api_gateway_rest_api" "lms_api" {
  name        = "${local.name_prefix}-api"
  description = "LMS REST API with full CORS and stable dev stage"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

#############################################
# RESOURCES
#############################################
resource "aws_api_gateway_resource" "courses" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  parent_id   = aws_api_gateway_rest_api.lms_api.root_resource_id
  path_part   = "courses"
}

resource "aws_api_gateway_resource" "course_by_id" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  parent_id   = aws_api_gateway_resource.courses.id
  path_part   = "{course_id}"
}

resource "aws_api_gateway_resource" "create_order" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  parent_id   = aws_api_gateway_rest_api.lms_api.root_resource_id
  path_part   = "create-order"
}

#############################################
# METHODS
#############################################
resource "aws_api_gateway_method" "get_courses" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = aws_api_gateway_resource.courses.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "get_course_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = aws_api_gateway_resource.course_by_id.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "post_create_order" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = aws_api_gateway_resource.create_order.id
  http_method   = "POST"
  authorization = "NONE"
}

# ✅ OPTIONS (CORS) for all
resource "aws_api_gateway_method" "options_courses" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = aws_api_gateway_resource.courses.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "options_course_by_id" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = aws_api_gateway_resource.course_by_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "options_create_order" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = aws_api_gateway_resource.create_order.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

#############################################
# INTEGRATIONS
#############################################
resource "aws_api_gateway_integration" "get_courses_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lms_api.id
  resource_id             = aws_api_gateway_resource.courses.id
  http_method             = aws_api_gateway_method.get_courses.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_courses.invoke_arn
}

resource "aws_api_gateway_integration" "get_course_by_id_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lms_api.id
  resource_id             = aws_api_gateway_resource.course_by_id.id
  http_method             = aws_api_gateway_method.get_course_by_id.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_courses.invoke_arn
}

resource "aws_api_gateway_integration" "create_order_integration" {
  rest_api_id             = aws_api_gateway_rest_api.lms_api.id
  resource_id             = aws_api_gateway_resource.create_order.id
  http_method             = aws_api_gateway_method.post_create_order.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_order.invoke_arn
}

# ✅ MOCK INTEGRATIONS for OPTIONS (CORS)
resource "aws_api_gateway_integration" "options_integration_courses" {
  rest_api_id             = aws_api_gateway_rest_api.lms_api.id
  resource_id             = aws_api_gateway_resource.courses.id
  http_method             = aws_api_gateway_method.options_courses.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration" "options_integration_course_by_id" {
  rest_api_id             = aws_api_gateway_rest_api.lms_api.id
  resource_id             = aws_api_gateway_resource.course_by_id.id
  http_method             = aws_api_gateway_method.options_course_by_id.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration" "options_integration_create_order" {
  rest_api_id             = aws_api_gateway_rest_api.lms_api.id
  resource_id             = aws_api_gateway_resource.create_order.id
  http_method             = aws_api_gateway_method.options_create_order.http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

#############################################
# CORS RESPONSES
#############################################
locals {
  cors_headers = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# Method responses for OPTIONS
resource "aws_api_gateway_method_response" "options_courses" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.courses.id
  http_method = aws_api_gateway_method.options_courses.http_method
  status_code = "200"
  response_parameters = local.cors_headers
}

resource "aws_api_gateway_method_response" "options_course_by_id" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.course_by_id.id
  http_method = aws_api_gateway_method.options_course_by_id.http_method
  status_code = "200"
  response_parameters = local.cors_headers
}

resource "aws_api_gateway_method_response" "options_create_order" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.create_order.id
  http_method = aws_api_gateway_method.options_create_order.http_method
  status_code = "200"
  response_parameters = local.cors_headers
}

# Integration responses for OPTIONS
# Integration responses for OPTIONS
resource "aws_api_gateway_integration_response" "options_courses" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.courses.id
  http_method = aws_api_gateway_method.options_courses.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Tenant-Id,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.options_integration_courses,
    aws_api_gateway_method_response.options_courses
  ]
}

resource "aws_api_gateway_integration_response" "options_course_by_id" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.course_by_id.id
  http_method = aws_api_gateway_method.options_course_by_id.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Tenant-Id,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.options_integration_course_by_id,
    aws_api_gateway_method_response.options_course_by_id
  ]
}

resource "aws_api_gateway_integration_response" "options_create_order" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.create_order.id
  http_method = aws_api_gateway_method.options_create_order.http_method
  status_code = "200"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Tenant-Id,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  depends_on = [
    aws_api_gateway_integration.options_integration_create_order,
    aws_api_gateway_method_response.options_create_order
  ]
}

#############################################
# DEPLOYMENT & STAGE
#############################################
resource "aws_api_gateway_deployment" "lms_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  description = "LMS API deployment for dev environment"

  triggers = {
    redeploy_hash = sha1(jsonencode([
      aws_api_gateway_integration.get_courses_integration.id,
      aws_api_gateway_integration.get_course_by_id_integration.id,
      aws_api_gateway_integration.create_order_integration.id,
      timestamp()
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.get_courses_integration,
    aws_api_gateway_integration.get_course_by_id_integration,
    aws_api_gateway_integration.create_order_integration,
    aws_api_gateway_integration.options_integration_courses,
    aws_api_gateway_integration.options_integration_course_by_id,
    aws_api_gateway_integration.options_integration_create_order
  ]
}

resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  deployment_id = aws_api_gateway_deployment.lms_api_deployment.id
  stage_name    = "dev"
  description   = "Development stage for LMS API"

  tags = {
    Environment = "dev"
  }

  lifecycle {
    create_before_destroy = true
  }
}

#############################################
# LAMBDA PERMISSIONS
#############################################
resource "aws_lambda_permission" "allow_api_gateway_list" {
  statement_id  = "AllowAPIGatewayInvokeList"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_courses.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lms_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_api_gateway_create_order" {
  statement_id  = "AllowAPIGatewayInvokeCreateOrder"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_order.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lms_api.execution_arn}/*/*"
}

#############################################
# OUTPUT
#############################################
output "api_invoke_url" {
  description = "Invoke URL for the API Gateway"
  value       = "https://${aws_api_gateway_rest_api.lms_api.id}.execute-api.${var.aws_region}.amazonaws.com/dev"
}