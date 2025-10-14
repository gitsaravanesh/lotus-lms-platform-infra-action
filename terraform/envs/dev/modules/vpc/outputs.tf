# VPC Outputs
output "vpc_id" {
  description = "The ID of the lotus-lms-platform VPC"
  value       = aws_vpc.lotus_lms_platform_vpc.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.lotus_lms_platform_vpc.cidr_block
}

# Public Subnet Outputs
output "public_subnet_id" {
  description = "The ID of the public subnet"
  value       = aws_subnet.lotus_lms_platform_public_subnet.id
}

output "public_subnet_cidr" {
  description = "The CIDR block of the public subnet"
  value       = aws_subnet.lotus_lms_platform_public_subnet.cidr_block
}

output "public_subnet_az" {
  description = "The availability zone of the public subnet"
  value       = aws_subnet.lotus_lms_platform_public_subnet.availability_zone
}

# Private Subnet Outputs
output "private_subnet_id" {
  description = "The ID of the private subnet"
  value       = aws_subnet.lotus_lms_platform_private_subnet.id
}

output "private_subnet_cidr" {
  description = "The CIDR block of the private subnet"
  value       = aws_subnet.lotus_lms_platform_private_subnet.cidr_block
}

output "private_subnet_az" {
  description = "The availability zone of the private subnet"
  value       = aws_subnet.lotus_lms_platform_private_subnet.availability_zone
}

# Common Tag (Optional, useful if using tagging strategy)
output "project_tag" {
  description = "Project name tag used for all resources"
  value       = "lotus-lms-platform"
}