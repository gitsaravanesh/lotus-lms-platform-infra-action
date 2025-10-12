output "ec2_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.lotus_lms_platform_ec2.id
}

output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.lotus_lms_platform_ec2.public_ip
}