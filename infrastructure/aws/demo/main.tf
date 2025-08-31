terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "OpenLIT"
      Environment = var.environment
      ManagedBy   = "Terraform"
      Purpose     = "Demo Environment"
      Owner       = "OpenLIT Team"
    }
  }
}

# Data sources for VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-arm64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group Module
module "security_group" {
  source = "../modules/security-group"

  environment   = var.environment
  vpc_id        = data.aws_vpc.default.id
  allowed_cidrs = var.allowed_cidrs
}

# EC2 OpenLIT Module
module "openlit_demo" {
  source = "../modules/ec2-openlit"

  environment        = var.environment
  instance_type      = var.instance_type
  key_pair_name      = var.key_pair_name
  security_group_id  = module.security_group.security_group_id
  subnet_id          = data.aws_subnets.default.ids[0]
  ami_id             = data.aws_ami.amazon_linux.id

  # Container configuration
  aws_account_id    = var.aws_account_id
  ecr_repository    = var.ecr_repository
  image_tag         = var.image_tag

  # ClickHouse configuration
  clickhouse_config = {
    host     = var.clickhouse_host
    port     = var.clickhouse_port
    database = var.clickhouse_database
    username = var.clickhouse_username
    password = var.clickhouse_password
  }

  # OTEL configuration
  otel_config = {
    host   = var.otel_host
    port   = var.otel_port
    secure = var.otel_secure
  }

  # Demo accounts
  demo_accounts = {
    emails    = var.demo_emails
    passwords = var.demo_passwords
  }
}
