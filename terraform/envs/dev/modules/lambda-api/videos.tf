# Videos (S3 + DynamoDB + IAM) resources inside the lambda-api module

resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "videos_bucket" {
  bucket = "lotus-lms-videos-${random_id.bucket_id.hex}-${var.environment}"

  tags = {
    Name        = "lotus-lms-videos"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_acl" "videos_bucket_acl" {
  bucket = aws_s3_bucket.videos_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_versioning" "videos_bucket_versioning" {
  bucket = aws_s3_bucket.videos_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "videos_bucket_lifecycle" {
  bucket = aws_s3_bucket.videos_bucket.id

  rule {
    id     = "noncurrent-version-expiration"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_dynamodb_table" "videos_table" {
  name         = "${var.project_prefix}-videos"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "course_id"
  range_key    = "video_id"

  attribute {
    name = "course_id"
    type = "S"
  }

  attribute {
    name = "video_id"
    type = "S"
  }

  tags = {
    Name        = "${var.project_prefix}-videos"
    Environment = var.environment
  }
}

data "aws_iam_policy_document" "backend_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = var.backend_principals
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "backend_role" {
  name               = "${var.project_prefix}-backend-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.backend_assume_role.json

  tags = {
    Name = "${var.project_prefix}-backend-role"
  }
}

data "aws_iam_policy_document" "backend_policy" {
  statement {
    sid     = "AllowDynamoDBForVideosTable"
    effect  = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem"
    ]
    resources = [
      aws_dynamodb_table.videos_table.arn,
      "${aws_dynamodb_table.videos_table.arn}/*"
    ]
  }

  statement {
    sid     = "AllowS3AccessToVideosBucket"
    effect  = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.videos_bucket.arn,
      "${aws_s3_bucket.videos_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "backend_policy" {
  name   = "${var.project_prefix}-backend-policy-${var.environment}"
  policy = data.aws_iam_policy_document.backend_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_backend_policy" {
  role       = aws_iam_role.backend_role.name
  policy_arn = aws_iam_policy.backend_policy.arn
}

# Module outputs (so the env-level module can re-export)
output "videos_bucket_name" {
  value = aws_s3_bucket.videos_bucket.bucket
}

output "videos_table_name" {
  value = aws_dynamodb_table.videos_table.name
}

output "backend_role_arn" {
  value = aws_iam_role.backend_role.arn
}

# Terraform snippet (example) to add the lambda + API Gateway resource and integration.
# Adapt and merge into module.lambda (or your lambda infra module). This is an example; you must
# adjust variable names, module structure and S3 artifact upload process to match your repo.

# 1) Add IAM inline policy (or managed policy) allowing DynamoDB Query on the videos table
resource "aws_iam_role_policy" "lambda_list_videos_policy" {
  name = "lms-infra-list-videos-policy"
  role = aws_iam_role.lambda_exec.name # adapt to your lambda exec role resource name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:Query",
          "dynamodb:GetItem",
          "dynamodb:Scan"
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/lotus-lms-videos",
          "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/lotus-lms-videos/*"
        ]
      }
    ]
  })
}

# 2) Lambda function resource
resource "aws_lambda_function" "list_videos" {
  function_name = "lms-infra-list-videos"
  runtime       = "python3.10"
  handler       = "handler.handler"
  role          = aws_iam_role.lambda_exec.arn  # ensure correct role with above policy attached

  # If you keep the same S3 bucket for artifacts:
  s3_bucket = aws_s3_bucket.lambda_artifacts.bucket
  s3_key    = "lambda/list_videos.zip"     # upload the zip during your build

  memory_size = 256
  timeout     = 10

  environment {
    variables = {
      VIDEOS_TABLE = "lotus-lms-videos"
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_list_videos_policy
  ]
}

# 3) API Gateway resource: attach under existing REST API

resource "aws_api_gateway_resource" "courses_id" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  parent_id   = aws_api_gateway_rest_api.lms_api.root_resource_id
  path_part   = "courses"
}

resource "aws_api_gateway_resource" "course_id_param" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  parent_id   = aws_api_gateway_resource.courses_id.id
  path_part   = "{course_id}"
}

resource "aws_api_gateway_resource" "course_videos" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  parent_id   = aws_api_gateway_resource.course_id_param.id
  path_part   = "videos"
}

# 4) Method + Integration (GET /courses/{course_id}/videos)
resource "aws_api_gateway_method" "get_course_videos" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = aws_api_gateway_resource.course_videos.id
  http_method   = "GET"
  authorization = "NONE"
  request_parameters = {
    "method.request.path.course_id" = true
  }
}

resource "aws_api_gateway_integration" "get_course_videos_integration" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.course_videos.id
  http_method = aws_api_gateway_method.get_course_videos.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_videos.invoke_arn
  timeout_milliseconds    = 29000
}

# 5) Response method for CORS (OPTIONS)
resource "aws_api_gateway_method" "options_course_videos" {
  rest_api_id   = aws_api_gateway_rest_api.lms_api.id
  resource_id   = aws_api_gateway_resource.course_videos.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "options_course_videos_integration" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.course_videos.id
  http_method = aws_api_gateway_method.options_course_videos.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "options_course_videos_200" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.course_videos.id
  http_method = aws_api_gateway_method.options_course_videos.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}

resource "aws_api_gateway_integration_response" "options_course_videos_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  resource_id = aws_api_gateway_resource.course_videos.id
  http_method = aws_api_gateway_method.options_course_videos.http_method
  status_code = aws_api_gateway_method_response.options_course_videos_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Tenant-Id,Authorization'"
  }

  response_templates = {
    "application/json" = ""
  }
}

# 6) Lambda permission so API Gateway can invoke
resource "aws_lambda_permission" "allow_api_gateway_list_videos" {
  statement_id  = "AllowAPIGatewayInvokeListVideos"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_videos.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lms_api.execution_arn}/*/*"
}