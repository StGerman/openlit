resource "aws_security_group" "openlit" {
  name_prefix = "openlit-${var.environment}-"
  description = "Security group for OpenLIT demo environment"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # OpenLIT UI
  ingress {
    description = "OpenLIT UI"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # OTEL Collector GRPC
  ingress {
    description = "OTEL Collector GRPC"
    from_port   = 4317
    to_port     = 4317
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # OTEL Collector HTTP
  ingress {
    description = "OTEL Collector HTTP"
    from_port   = 4318
    to_port     = 4318
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # OTEL Collector metrics
  ingress {
    description = "OTEL Collector metrics"
    from_port   = 8888
    to_port     = 8888
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidrs
  }

  # All outbound traffic
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "openlit-${var.environment}-sg"
    Environment = var.environment
    Purpose     = "OpenLIT Demo Security Group"
  }
}
