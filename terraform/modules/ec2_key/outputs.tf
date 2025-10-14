output "key_name" {
  description = "The name of the EC2 key pair"
  value       = aws_key_pair.lotus_lms_platform_key.key_name
}

output "private_key_path" {
  description = "Local path of the private key PEM file"
  value       = local_file.private_key_pem.filename
}

output "private_key_pem" {
  description = "Private key content (sensitive)"
  value       = tls_private_key.lotus_lms_platform_ssh_key.private_key_pem
  sensitive   = true
}