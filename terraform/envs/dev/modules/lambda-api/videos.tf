# Videos (S3 + DynamoDB + IAM) resources inside the lambda-api module

resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "videos_bucket" {
  bucket = "${var.project_prefix}-videos-${random_id.bucket_id.hex}-${var.environment}"
  acl    = "private"

  versioning {
    enabled = true
  }

  lifecycle_rule {
    id      = "noncurrent-version-expiration"
    enabled = true

    noncurrent_version_expiration {
      days = 30
    }
  }

  tags = {
    Name        = "${var.project_prefix}-videos"
    Environment = var.environment
  }
}

resource "aws_dynamodb_table" "videos_table" {
  name         = "${var.project_prefix}-videos-${var.environment}"
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