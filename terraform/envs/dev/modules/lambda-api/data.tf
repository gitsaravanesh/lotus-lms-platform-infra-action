# Add these data sources if they don't already exist in your lambda module
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}