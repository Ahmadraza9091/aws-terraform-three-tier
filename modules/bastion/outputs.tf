output "public_ip" {
  description = "Public IPv4 address of the bastion host"
  value       = aws_instance.bastion.public_ip
}
