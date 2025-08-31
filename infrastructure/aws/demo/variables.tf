variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (demo, staging, production)"
  type        = string
  default     = "demo"
}

variable "instance_type" {
  description = "EC2 instance type (Graviton preferred)"
  type        = string
  default     = "t4g.small"
}

variable "key_pair_name" {
  description = "AWS EC2 key pair name for SSH access"
  type        = string
}

variable "allowed_cidrs" {
  description = "List of CIDR blocks allowed to access the instance"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production
}

# Container Configuration
variable "aws_account_id" {
  description = "AWS Account ID for ECR access"
  type        = string
}

variable "ecr_repository" {
  description = "ECR repository name for OpenLIT images"
  type        = string
  default     = "openlit-vostok"
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

# ClickHouse Configuration
variable "clickhouse_host" {
  description = "ClickHouse Cloud host URL"
  type        = string
}

variable "clickhouse_port" {
  description = "ClickHouse port"
  type        = string
  default     = "8443"
}

variable "clickhouse_database" {
  description = "ClickHouse database name"
  type        = string
  default     = "openlit"
}

variable "clickhouse_username" {
  description = "ClickHouse username"
  type        = string
  default     = "default"
}

variable "clickhouse_password" {
  description = "ClickHouse password"
  type        = string
  sensitive   = true
}

# OTEL Configuration
variable "otel_host" {
  description = "OTEL collector host"
  type        = string
}

variable "otel_port" {
  description = "OTEL collector port"
  type        = string
  default     = "9440"
}

variable "otel_secure" {
  description = "Use secure connection for OTEL"
  type        = bool
  default     = true
}

# Demo Accounts
variable "demo_emails" {
  description = "Comma-separated list of demo account emails"
  type        = string
}

variable "demo_passwords" {
  description = "Comma-separated list of demo account passwords"
  type        = string
  sensitive   = true
}
