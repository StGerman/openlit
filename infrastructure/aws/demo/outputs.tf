output "instance_id" {
  description = "ID of the OpenLIT EC2 instance"
  value       = module.openlit_demo.instance_id
}

output "instance_public_ip" {
  description = "Public IP address of the OpenLIT instance"
  value       = module.openlit_demo.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the OpenLIT instance"
  value       = module.openlit_demo.private_ip
}

output "openlit_url" {
  description = "URL to access OpenLIT UI"
  value       = "http://${module.openlit_demo.public_ip}:3000"
}

output "otel_endpoints" {
  description = "OTEL collector endpoints"
  value = {
    grpc = "http://${module.openlit_demo.public_ip}:4317"
    http = "http://${module.openlit_demo.public_ip}:4318"
  }
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${var.key_pair_name}.pem ec2-user@${module.openlit_demo.public_ip}"
}

output "security_group_id" {
  description = "ID of the OpenLIT security group"
  value       = module.security_group.security_group_id
}

output "deployment_info" {
  description = "Complete deployment information"
  value = {
    environment     = var.environment
    instance_type   = var.instance_type
    aws_region      = var.aws_region
    ecr_repository  = "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.ecr_repository}:${var.image_tag}"
  }
}
