locals {
  name_prefix = "lms-infra"
}

#############################################
# S3 BUCKET FOR LAMBDA ARTIFACTS
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
        Action = ["dynamodb:GetItem", "dynamodb:Query", "dynamodb:Scan"]
        Resource = aws_dynamodb_table.courses.arn
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.lambda_artifacts.arn}/*"
      }
    ]
  })
}

#############################################
# LAMBDA FUNCTIONS
#############################################

# List Courses Lambda
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

  depends_on = [aws_iam_role_policy.lambda_policy]
}

# Create Order Lambda
resource "aws_lambda_function" "create_order" {
  function_name = "${local.name_prefix}-create-order"
  role          = aws_iam_role.lambda_exec.arn
  runtime       = var.lambda_runtime
  handler       = "create_order.lambda_handler"
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

  depends_on = [aws_iam_role_policy.lambda_policy]
}

#############################################
# API GATEWAY REST API
#############################################
resource "aws_api_gateway_rest_api" "lms_api" {
  name        = "${local.name_prefix}-api"
  description = "LMS REST API with CORS and Lambda integrations"
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

# OPTIONS for CORS
resource "aws_api_gateway_method" "options_all" {
  for_each = {
    courses      = aws_api_gateway_resource.courses.id
    course_by_id = aws_api_gateway_resource.course_by_id.id
    create_order = aws_api_gateway_resource.create_order.id
  }

  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = each.value
  http_method   = "OPTIONS"
  authorization = "NONE"
}

#############################################
# INTEGRATIONS
#############################################
resource "aws_api_gateway_integration" "get_courses" {
  rest_api_id             = aws_api_gateway_rest_api.lms_api.id
  resource_id             = aws_api_gateway_resource.courses.id
  http_method             = aws_api_gateway_method.get_courses.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_courses.invoke_arn
}

resource "aws_api_gateway_integration" "get_course_by_id" {
  rest_api_id             = aws_api_gateway_rest_api.lms_api.id
  resource_id             = aws_api_gateway_resource.course_by_id.id
  http_method             = aws_api_gateway_method.get_course_by_id.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_courses.invoke_arn
}

resource "aws_api_gateway_integration" "create_order" {
  rest_api_id             = aws_api_gateway_rest_api.lms_api.id
  resource_id             = aws_api_gateway_resource.create_order.id
  http_method             = aws_api_gateway_method.post_create_order.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.create_order.invoke_arn
}

# CORS MOCK integrations
resource "aws_api_gateway_integration" "options_cors" {
  for_each = {
    courses      = aws_api_gateway_resource.courses.id
    course_by_id = aws_api_gateway_resource.course_by_id.id
    create_order = aws_api_gateway_resource.create_order.id
  }

  rest_api_id             = aws_api_gateway_rest_api.lms_api.id
  resource_id             = each.value
  http_method             = aws_api_gateway_method.options_all[each.key].http_method
  type                    = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

#############################################
# CORS RESPONSES
#############################################
resource "aws_api_gateway_method_response" "cors" {
  for_each = aws_api_gateway_method.options_all

  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "cors" {
  for_each = aws_api_gateway_method.options_all

  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = each.value.resource_id
  http_method = each.value.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Tenant-Id,Authorization'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

#############################################
# DEPLOYMENT & STAGE (with auto-redeploy)
#############################################
resource "aws_api_gateway_deployment" "lms_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  description = "LMS API deployment"

  triggers = {
    redeploy_hash = sha1(jsonencode([
      aws_api_gateway_integration.get_courses.id,
      aws_api_gateway_integration.create_order.id,
      aws_api_gateway_integration.get_course_by_id.id
    ]))
  }

  depends_on = [
    aws_api_gateway_integration.get_courses,
    aws_api_gateway_integration.get_course_by_id,
    aws_api_gateway_integration.create_order,
    aws_api_gateway_integration.options_cors
  ]
}

resource "aws_api_gateway_stage" "dev" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  deployment_id = aws_api_gateway_deployment.lms_api_deployment.id
  stage_name    = "dev"
  description   = "Development stage"
  tags = {
    Environment = "dev"
  }
}

#############################################
# PERMISSIONS
#############################################
resource "aws_lambda_permission" "allow_list_courses" {
  statement_id  = "AllowAPIGatewayInvokeListCourses"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_courses.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lms_api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "allow_create_order" {
  statement_id  = "AllowAPIGatewayInvokeCreateOrder"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_order.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lms_api.execution_arn}/*/*"
}