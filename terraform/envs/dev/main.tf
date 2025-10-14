# EC2 Key Pair Module
module "ec2_key" {
  source = "/modules/ec2_key"
  key_name = "lotus-lms-platform-key"
}

# VPC Module
module "vpc" {
  source         = "/modules/vpc"
  aws_region     = var.aws_region
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
}

# EC2 Module
#module "ec2" {
#  source       = "./ec2"
#  ami_id       = "ami-02d26659fd82cf299"   # Example Amazon Linux 2 AMI (us-east-1)
#  instance_type = "t2.micro"
#  subnet_id    = module.vpc.public_subnet_id
#  key_name      = module.ec2_key.key_name
#}

module "cognito" {
  source = "/modules/cognito"

  user_pool_name        = "lms-userpool-dev"
  cognito_domain_prefix = "lms-auth-dev-sarav"   # must be globally unique

  callback_urls = [
    "https://lms-dev.example.com/auth/callback",
  ]

  logout_urls = [
    "https://lms-dev.example.com/",
  ]

  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret

  enabled_identity_providers = ["Google"]
}
