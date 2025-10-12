output "lotus_lms_platform_vpc_id" {
  description = "The ID of the lotus-lms-platform VPC"
  value       = aws_vpc.lotus_lms_platform_vpc.id
}

output "lotus_lms_platform_public_subnet_id" {
  description = "The ID of the lotus-lms-platform public subnet"
  value       = aws_subnet.lotus_lms_platform_public_subnet.id
}

output "lotus_lms_platform_private_subnet_id" {
  description = "The ID of the lotus-lms-platform private subnet"
  value       = aws_subnet.lotus_lms_platform_private_subnet.id
}