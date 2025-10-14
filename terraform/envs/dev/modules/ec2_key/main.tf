#####################################
# EC2 Key Pair Module
# Generates an SSH key, uploads to AWS, and saves locally
#####################################

resource "tls_private_key" "lotus_lms_platform_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "lotus_lms_platform_key" {
  key_name   = var.key_name
  public_key = tls_private_key.lotus_lms_platform_ssh_key.public_key_openssh

  tags = {
    Name    = var.key_name
    Project = "lotus-lms-platform"
  }
}

resource "local_file" "private_key_pem" {
  content              = tls_private_key.lotus_lms_platform_ssh_key.private_key_pem
  filename             = "${path.module}/${var.key_name}.pem"
  file_permission      = "0400"
  directory_permission = "0700"
}