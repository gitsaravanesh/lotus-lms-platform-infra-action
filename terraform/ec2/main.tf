resource "aws_instance" "lotus_lms_platform_ec2" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  associate_public_ip_address = true
  key_name               = var.key_name

  tags = {
    Name = "lotus-lms-platform-ec2"
  }
}