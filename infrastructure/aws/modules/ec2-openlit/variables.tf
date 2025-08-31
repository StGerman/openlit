variable "environment" {
  description = "Environment name"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.small"
}

variable "key_pair_name" {
  description = "AWS EC2 key pair name for SSH access"
  type        = string
}

variable "security_group_id" {
  description = "Security group ID to assign to the instance"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be launched"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

# Container Configuration
variable "aws_account_id" {
  description = "AWS Account ID for ECR access"
  type        = string
}

variable "ecr_repository" {
  description = "ECR repository name"
  type        = string
}

variable "image_tag" {
  description = "Docker image tag"
  type        = string
  default     = "latest"
}

# ClickHouse Configuration
variable "clickhouse_config" {
  description = "ClickHouse connection configuration"
  type = object({
    host     = string
    port     = string
    database = string
    username = string
    password = string
  })
  sensitive = true
}

# OTEL Configuration
variable "otel_config" {
  description = "OTEL collector configuration"
  type = object({
    host   = string
    port   = string
    secure = bool
  })
}

# Demo Accounts
variable "demo_accounts" {
  description = "Demo account configuration"
  type = object({
    emails    = string
    passwords = string
  })
  sensitive = true
}
