terraform {
  backend "s3" {
    bucket         = "lotus-lms-terraform-state"
    key            = "env/dev/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "lotus-lms-terraform-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.4.0"
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "aws_access_key" {
  description = "AWS Access Key"
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  sensitive   = true
}

# EC2 Key Pair Module
module "ec2_key" {
  source   = "./ec2_key"
  key_name = "lotus-lms-platform-key"
}

# VPC Module
module "vpc" {
  source         = "./vpc"
  aws_region     = var.aws_region
  aws_access_key = var.aws_access_key
  aws_secret_key = var.aws_secret_key
}

# EC2 Module
module "ec2" {
  source       = "./ec2"
  ami_id       = "ami-02d26659fd82cf299"   # Example Amazon Linux 2 AMI (us-east-1)
  instance_type = "t2.micro"
  subnet_id    = module.vpc.public_subnet_id
  key_name      = module.ec2_key.key_name
}