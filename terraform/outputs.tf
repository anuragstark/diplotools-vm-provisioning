output "ec2_public_ip" {
  description = "The public IP address of the newly provisioned EC2 instance."
  value       = aws_instance.app_server.public_ip
}

output "environment" {
  description = "The environment (workspace) that was deployed."
  value       = var.environment
}
