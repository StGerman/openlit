# IAM Role for EC2 instance to access ECR
resource "aws_iam_role" "openlit_ec2_role" {
  name = "openlit-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "openlit-${var.environment}-ec2-role"
    Environment = var.environment
  }
}

# IAM Policy for ECR access
resource "aws_iam_role_policy" "openlit_ecr_policy" {
  name = "openlit-${var.environment}-ecr-policy"
  role = aws_iam_role.openlit_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "openlit_profile" {
  name = "openlit-${var.environment}-instance-profile"
  role = aws_iam_role.openlit_ec2_role.name

  tags = {
    Name        = "openlit-${var.environment}-instance-profile"
    Environment = var.environment
  }
}

# Elastic IP for stable public address
resource "aws_eip" "openlit" {
  domain = "vpc"

  tags = {
    Name        = "openlit-${var.environment}-eip"
    Environment = var.environment
  }
}

# Process user data template
locals {
  user_data = templatefile("${path.module}/../../demo/user-data.sh", {
    clickhouse_host     = var.clickhouse_config.host
    clickhouse_port     = var.clickhouse_config.port
    clickhouse_database = var.clickhouse_config.database
    clickhouse_username = var.clickhouse_config.username
    clickhouse_password = var.clickhouse_config.password
    otel_host           = var.otel_config.host
    otel_port           = var.otel_config.port
    demo_email_1        = split(",", var.demo_accounts.emails)[0]
    demo_password_1     = split(",", var.demo_accounts.passwords)[0]
    aws_account_id      = var.aws_account_id
    aws_region          = data.aws_region.current.name
    ecr_repository      = var.ecr_repository
    image_tag           = var.image_tag
  })
}

# Get current AWS region
data "aws_region" "current" {}

# EC2 Instance
resource "aws_instance" "openlit" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  iam_instance_profile   = aws_iam_instance_profile.openlit_profile.name

  user_data = base64encode(local.user_data)

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true
    delete_on_termination = true
  }

  tags = {
    Name        = "openlit-${var.environment}"
    Environment = var.environment
    Purpose     = "OpenLIT Demo Instance"
  }
}

# Associate Elastic IP with instance
resource "aws_eip_association" "openlit" {
  instance_id   = aws_instance.openlit.id
  allocation_id = aws_eip.openlit.id
}
