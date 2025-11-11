# Random ID for unique bucket naming (may already exist in your module)
resource "random_id" "bucket_id" {
  byte_length = 4
}

# S3 bucket for videos
resource "aws_s3_bucket" "videos_bucket" {
  bucket = "lotus-lms-videos-${random_id.bucket_id.hex}-${var.environment}"

  tags = {
    Name        = "lotus-lms-videos"
    Environment = var.environment
  }
}

# Enable bucket ownership controls (required for ACLs)
resource "aws_s3_bucket_ownership_controls" "videos_bucket_ownership" {
  bucket = aws_s3_bucket.videos_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Disable public access
resource "aws_s3_bucket_public_access_block" "videos_bucket_public_access" {
  bucket = aws_s3_bucket.videos_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ACL (after ownership controls)
resource "aws_s3_bucket_acl" "videos_bucket_acl" {
  depends_on = [
    aws_s3_bucket_ownership_controls.videos_bucket_ownership,
    aws_s3_bucket_public_access_block.videos_bucket_public_access
  ]

  bucket = aws_s3_bucket.videos_bucket.id
  acl    = "private"
}

# Versioning
resource "aws_s3_bucket_versioning" "videos_bucket_versioning" {
  bucket = aws_s3_bucket.videos_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Lifecycle configuration (FIXED: added filter block)
resource "aws_s3_bucket_lifecycle_configuration" "videos_bucket_lifecycle" {
  bucket = aws_s3_bucket.videos_bucket.id

  rule {
    id     = "noncurrent-version-expiration"
    status = "Enabled"

    # Add this filter block to fix the warning/error
    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# DynamoDB table for videos metadata
resource "aws_dynamodb_table" "videos_table" {
  name         = "lotus-lms-videos"
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
    Name        = "lotus-lms-videos"
    Environment = var.environment
  }
}

# IAM policy for list_videos Lambda
resource "aws_iam_role_policy" "lambda_list_videos_policy" {
  name = "lms-infra-list-videos-policy"
  role = aws_iam_role.lambda_exec.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:Query",
          "dynamodb:GetItem",
          "dynamodb:Scan"
        ]
        Effect = "Allow"
        Resource = [
          aws_dynamodb_table.videos_table.arn,
          "${aws_dynamodb_table.videos_table.arn}/*"
        ]
      },
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.videos_bucket.arn,
          "${aws_s3_bucket.videos_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Create placeholder zip if it doesn't exist (FIXED: prevents Lambda creation error)
resource "null_resource" "create_placeholder_zip" {
  provisioner "local-exec" {
    command = <<-EOT
      if ! aws s3 ls s3://${aws_s3_bucket.lambda_artifacts.bucket}/lambda/list_videos.zip 2>/dev/null; then
        mkdir -p /tmp/lambda_placeholder
        echo 'def handler(event, context): return {"statusCode": 200, "body": "placeholder"}' > /tmp/lambda_placeholder/handler.py
        cd /tmp/lambda_placeholder && zip -r /tmp/list_videos_placeholder.zip . && cd -
        aws s3 cp /tmp/list_videos_placeholder.zip s3://${aws_s3_bucket.lambda_artifacts.bucket}/lambda/list_videos.zip
        rm -rf /tmp/lambda_placeholder /tmp/list_videos_placeholder.zip
      fi
    EOT
  }

  depends_on = [aws_s3_bucket.lambda_artifacts]
}

# Lambda function for list_videos
resource "aws_lambda_function" "list_videos" {
  function_name = "lms-infra-list-videos"
  runtime       = "python3.10"
  handler       = "handler.handler"
  role          = aws_iam_role.lambda_exec.arn

  s3_bucket = aws_s3_bucket.lambda_artifacts.bucket
  s3_key    = "lambda/list_videos.zip"

  memory_size = 256
  timeout     = 10

  environment {
    variables = {
      VIDEOS_TABLE = aws_dynamodb_table.videos_table.name
    }
  }

  depends_on = [
    aws_iam_role_policy.lambda_list_videos_policy,
    null_resource.create_placeholder_zip
  ]

  lifecycle {
    ignore_changes = [
      # Ignore changes to source code hash since we update via GitHub Actions
      source_code_hash
    ]
  }
}

# FIXED: Don't recreate existing /courses resource - reference it instead
# Remove or comment out this block if aws_api_gateway_resource.courses already exists
# resource "aws_api_gateway_resource" "courses_id" {
#   rest_api_id = aws_api_gateway_rest_api.lms_api.id
#   parent_id   = aws_api_gateway_rest_api.lms_api.root_resource_id
#   path_part   = "courses"
# }

# Use existing course_by_id resource (assumes it exists as /courses/{course_id})
# If you don't have this, you need to reference your existing structure

# API Gateway resource: /courses/{course_id}/videos
resource "aws_api_gateway_resource" "course_videos" {
  rest_api_id = aws_api_gateway_rest_api.lms_api.id
  # FIXED: Use existing course_by_id resource instead of creating new courses resource
  parent_id   = aws_api_gateway_resource.course_by_id.id
  path_part   = "videos"
}

# GET method
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

# OPTIONS method for CORS
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

  depends_on = [
    aws_api_gateway_integration.options_course_videos_integration
  ]
}

# Lambda permission
resource "aws_lambda_permission" "allow_api_gateway_list_videos" {
  statement_id  = "AllowAPIGatewayInvokeListVideos"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list_videos.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.lms_api.execution_arn}/*/*"
}