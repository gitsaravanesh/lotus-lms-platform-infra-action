# KMS key for Terraform state encryption
resource "aws_kms_key" "lotus_lms_platform_state_key" {
  description             = "KMS key for encrypting Terraform state and other resources"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name    = "lotus-lms-platform-kms"
    Project = "lotus-lms-platform"
  }
}

# Optional alias for easier reference
resource "aws_kms_alias" "lotus_lms_platform_state_alias" {
  name          = "alias/lotus-lms-platform-state"
  target_key_id = aws_kms_key.lotus_lms_platform_state_key.key_id
}