output "security_group_id" {
  description = "ID of the created security group"
  value       = aws_security_group.openlit.id
}

output "security_group_arn" {
  description = "ARN of the created security group"
  value       = aws_security_group.openlit.arn
}
