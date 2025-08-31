output "instance_id" {
  description = "ID of the OpenLIT EC2 instance"
  value       = aws_instance.openlit.id
}

output "public_ip" {
  description = "Public IP address of the OpenLIT instance"
  value       = aws_eip.openlit.public_ip
}

output "private_ip" {
  description = "Private IP address of the OpenLIT instance"
  value       = aws_instance.openlit.private_ip
}

output "instance_arn" {
  description = "ARN of the OpenLIT instance"
  value       = aws_instance.openlit.arn
}

output "eip_id" {
  description = "Elastic IP allocation ID"
  value       = aws_eip.openlit.id
}
