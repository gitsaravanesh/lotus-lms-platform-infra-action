# EC2 Key Pair Module
module "ec2_key" {
  source = "./modules/ec2_key"
  key_name = "lotus-lms-platform-key"
}

# VPC Module
module "vpc" {
  source         = "./modules/vpc"
  aws_region     = var.aws_region
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
  source = "./modules/cognito"

  user_pool_name        = "lms-userpool-dev"
  cognito_domain_prefix = "lms-auth-dev-sarav"   # must be globally unique

  callback_urls = [
    "https://lms-frontend-dev-sarav.s3-website.ap-south-1.amazonaws.com",
  ]

  logout_urls = [
    "https://lms-frontend-dev-sarav.s3-website.ap-south-1.amazonaws.com",
  ]

  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret

  enabled_identity_providers = ["Google"]
}

module "s3" {
  source = "./modules/s3"

  bucket_name = "lms-frontend-dev-${random_id.suffix.hex}"
  environment = "dev"

  providers = {
    aws = aws
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

module "cloudfront" {
  source              = "./modules/cloudfront"
  bucket_name         = module.s3.bucket_name
  domain_name         = "app.blackgardentech.in"     # or dev subdomain
  environment         = var.environment
  acm_certificate_arn = var.acm_certificate_arn
}

output "cloudfront_url" {
  value = module.cloudfront.cloudfront_distribution_domain
}