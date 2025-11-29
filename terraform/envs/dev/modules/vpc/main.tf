terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.4.0"
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "lotus_lms_platform_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name    = "lotus-lms-platform-vpc"
    Project = "lotus-lms-platform"
  }
}

# Public Subnet
resource "aws_subnet" "lotus_lms_platform_public_subnet" {
  vpc_id                  = aws_vpc.lotus_lms_platform_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = {
    Name    = "lotus-lms-platform-public-subnet"
    Project = "lotus-lms-platform"
  }
}

# Private Subnet
resource "aws_subnet" "lotus_lms_platform_private_subnet" {
  vpc_id                  = aws_vpc.lotus_lms_platform_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "${var.aws_region}b"

  tags = {
    Name    = "lotus-lms-platform-private-subnet"
    Project = "lotus-lms-platform"
  }
}