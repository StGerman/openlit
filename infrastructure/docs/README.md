# OpenLIT AWS EC2 Infrastructure

This directory contains Terraform configurations and automation scripts for deploying OpenLIT on AWS EC2 using Graviton instances.

## Quick Start

### 1. Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0 installed
- Docker with buildx support
- EC2 key pair created in your target region

### 2. Configuration
```bash
cd infrastructure/aws/demo
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Deploy
```bash
cd infrastructure/scripts
./deploy.sh
```

### 4. Health Check
```bash
./health-check.sh
```

### 5. Cleanup
```bash
./destroy.sh
```

## Directory Structure

```
infrastructure/
├── aws/
│   ├── demo/                    # Demo environment configuration
│   │   ├── main.tf             # Main Terraform configuration
│   │   ├── variables.tf        # Variable definitions
│   │   ├── outputs.tf          # Output definitions
│   │   ├── versions.tf         # Provider version constraints
│   │   ├── user-data.sh        # EC2 user data script
│   │   ├── terraform.tfvars.example  # Example configuration
│   │   └── terraform.tfvars    # Your configuration (gitignored)
│   └── modules/
│       ├── ec2-openlit/        # OpenLIT EC2 instance module
│       └── security-group/     # Security group module
├── scripts/
│   ├── deploy.sh              # Main deployment script
│   ├── health-check.sh        # Health check and monitoring
│   ├── build-and-push.sh      # Docker build and ECR push
│   └── destroy.sh             # Cleanup and destruction
└── docs/
    └── README.md              # This file
```

## Configuration

### Required Variables (terraform.tfvars)

```hcl
# Infrastructure
aws_region    = "us-east-1"
environment   = "demo"
instance_type = "t4g.small"
key_pair_name = "your-key-pair-name"
allowed_cidrs = ["YOUR.IP.ADDRESS/32"]

# Container Configuration
aws_account_id = "123456789012"
ecr_repository = "openlit-vostok"
image_tag      = "latest"

# ClickHouse Configuration
clickhouse_host     = "https://your-clickhouse-host"
clickhouse_port     = "8443"
clickhouse_database = "openlit"
clickhouse_username = "default"
clickhouse_password = "your-password"

# OTEL Configuration
otel_host   = "your-otel-host"
otel_port   = "9440"
otel_secure = true

# Demo Accounts
demo_emails    = "user1@example.com,user2@example.com"
demo_passwords = "password1,password2"
```

## Deployment Process

### Automated Deployment
The `deploy.sh` script handles the complete deployment:

1. **Prerequisites Check**: Validates tools and AWS authentication
2. **Image Build**: Builds ARM64 OpenLIT image and pushes to ECR
3. **Infrastructure**: Deploys EC2 instance, security groups, and networking
4. **Health Check**: Validates all services are running correctly

### Manual Steps (if needed)

#### 1. Build and Push Image
```bash
cd infrastructure/scripts
./build-and-push.sh latest
```

#### 2. Deploy Infrastructure
```bash
cd infrastructure/aws/demo
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

#### 3. Verify Deployment
```bash
cd infrastructure/scripts
./health-check.sh
```

## Instance Configuration

### Instance Specifications
- **Type**: t4g.small (2 vCPU, 2 GiB RAM, ARM64)
- **Platform**: Amazon Linux 2 ARM64
- **Storage**: 20GB GP3 encrypted EBS volume
- **Network**: Public subnet with Elastic IP

### Installed Services
- **Docker**: Container runtime
- **Docker Compose**: Service orchestration
- **OpenLIT UI**: Port 3000
- **OTEL Collector**: Ports 4317 (GRPC), 4318 (HTTP), 8888 (metrics)

### Security Configuration
- SSH access restricted to specified CIDR blocks
- Application ports restricted to specified CIDR blocks
- IAM role with minimal ECR permissions
- EBS volume encryption enabled

## Monitoring and Troubleshooting

### Health Checks
```bash
# Full health check
./health-check.sh

# Individual service checks
./health-check.sh ui          # OpenLIT UI only
./health-check.sh otel        # OTEL Collector only
./health-check.sh aws         # EC2 instance only
./health-check.sh docker      # Docker services only
```

### Access Information
```bash
# Get deployment info
./health-check.sh info

# SSH to instance
ssh -i your-key.pem ec2-user@$(cd ../aws/demo && terraform output -raw instance_public_ip)
```

### Common Issues

#### Container Startup Issues
```bash
# SSH to instance and check logs
ssh -i your-key.pem ec2-user@INSTANCE_IP
cd /home/ec2-user/openlit
sudo docker-compose logs -f
```

#### ECR Authentication Issues
```bash
# Re-authenticate with ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com
```

#### Service Not Starting
```bash
# Check systemd service
sudo systemctl status openlit.service
sudo journalctl -u openlit.service -f
```

## Cost Optimization

### Monthly Costs (us-east-1)
- **EC2 t4g.small**: ~$13.14/month
- **EBS 20GB gp3**: ~$1.60/month
- **Elastic IP**: ~$3.65/month
- **Data Transfer**: ~$0.50/month
- **Total**: ~$18.89/month

### Cost Management
- Instance automatically stops if not used (add auto-stop scripts if needed)
- EBS volume optimized with gp3
- Graviton instances provide 20% better price-performance
- No additional AWS services required (uses external ClickHouse Cloud)

## Security Notes

### Network Security
- Security groups restrict access to specified IP addresses only
- All inbound traffic requires explicit CIDR configuration
- SSH key-based authentication required

### Data Security
- EBS volumes encrypted at rest
- ClickHouse credentials stored as Terraform sensitive variables
- IAM roles follow principle of least privilege

### Access Control
- Separate IAM role for EC2 instance
- ECR access limited to required operations only
- Demo accounts with limited permissions

## Development Workflow

### Making Changes
1. Modify OpenLIT source code
2. Build new image: `./build-and-push.sh dev-$(date +%Y%m%d)`
3. Update `image_tag` in terraform.tfvars
4. Redeploy: `terraform apply -var-file="terraform.tfvars"`

### Testing Changes
```bash
# Test build locally first
./build-and-push.sh test dev-test

# Deploy to test environment
# (copy terraform.tfvars to test configuration)
```

## Cleanup

### Temporary Cleanup
```bash
# Stop services but keep infrastructure
ssh -i your-key.pem ec2-user@INSTANCE_IP
cd /home/ec2-user/openlit
sudo docker-compose down
```

### Complete Cleanup
```bash
cd infrastructure/scripts
./destroy.sh
```

This will remove:
- EC2 instance and associated resources
- Elastic IP address
- Security groups
- IAM roles and policies

**Note**: ECR repository and images are preserved by default unless explicitly deleted.

## Support

For issues with this deployment:
1. Check health-check.sh output for service status
2. Review AWS CloudTrail for permission issues
3. Check EC2 instance logs via SSH
4. Verify ClickHouse Cloud connectivity

For OpenLIT application issues, refer to the main OpenLIT documentation.
