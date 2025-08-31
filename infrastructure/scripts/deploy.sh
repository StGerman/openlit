#!/bin/bash
set -e

# OpenLIT AWS EC2 Deployment Script
# This script handles the complete deployment process

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../aws/demo"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check required tools
    for tool in terraform aws docker; do
        if ! command -v $tool &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done

    # Check AWS authentication
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI not configured. Run 'aws configure' first."
        exit 1
    fi

    # Check if terraform.tfvars exists
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        log_error "terraform.tfvars not found. Copy from terraform.tfvars.example and configure."
        exit 1
    fi

    log_success "All prerequisites met"
}

# Build and push Docker image
build_and_push_image() {
    log_info "Building and pushing OpenLIT Docker image..."

    cd "$PROJECT_ROOT"

    # Get AWS account ID and region
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    AWS_REGION=$(grep '^aws_region' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
    ECR_REPOSITORY=$(grep '^ecr_repository' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
    IMAGE_TAG=$(grep '^image_tag' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)

    log_info "Building for ARM64 (Graviton) architecture..."

    # Create ECR repository if it doesn't exist
    aws ecr describe-repositories --repository-names $ECR_REPOSITORY --region $AWS_REGION 2>/dev/null || {
        log_info "Creating ECR repository $ECR_REPOSITORY..."
        aws ecr create-repository --repository-name $ECR_REPOSITORY --region $AWS_REGION
    }

    # Login to ECR
    aws ecr get-login-password --region $AWS_REGION | \
        docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

    # Build and push ARM64 image
    docker buildx build \
        --platform linux/arm64 \
        --file src/client/Dockerfile \
        --tag $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG \
        --push \
        src/client/

    log_success "Docker image built and pushed to ECR"
    log_info "Image: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG"
}

# Deploy infrastructure
deploy_infrastructure() {
    log_info "Deploying infrastructure with Terraform..."

    cd "$TERRAFORM_DIR"

    # Initialize Terraform
    terraform init

    # Validate configuration
    terraform validate

    # Plan deployment
    log_info "Creating deployment plan..."
    terraform plan -var-file="terraform.tfvars" -out="tfplan"

    # Apply deployment
    log_info "Applying deployment..."
    terraform apply "tfplan"

    log_success "Infrastructure deployed successfully"
}

# Health check
health_check() {
    log_info "Running health checks..."

    cd "$TERRAFORM_DIR"

    # Get instance IP
    INSTANCE_IP=$(terraform output -raw instance_public_ip)

    log_info "Instance IP: $INSTANCE_IP"
    log_info "Waiting for services to start (this may take 3-5 minutes)..."

    # Wait for OpenLIT UI
    for i in {1..30}; do
        if curl -f -s "http://$INSTANCE_IP:3000/api/health" &> /dev/null; then
            log_success "OpenLIT UI is responding"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "OpenLIT UI failed to start after 5 minutes"
            return 1
        fi
        sleep 10
    done

    # Check OTEL endpoints
    if curl -f -s "http://$INSTANCE_IP:8888/" &> /dev/null; then
        log_success "OTEL Collector is responding"
    else
        log_warning "OTEL Collector may not be ready yet"
    fi

    log_success "Health checks completed"
    log_info "OpenLIT UI: http://$INSTANCE_IP:3000"
    log_info "OTEL GRPC: http://$INSTANCE_IP:4317"
    log_info "OTEL HTTP: http://$INSTANCE_IP:4318"
}

# Main deployment function
main() {
    log_info "🚀 Starting OpenLIT AWS EC2 Deployment"
    log_info "========================================"

    check_prerequisites
    build_and_push_image
    deploy_infrastructure
    health_check

    log_success "🎉 Deployment completed successfully!"

    cd "$TERRAFORM_DIR"
    INSTANCE_IP=$(terraform output -raw instance_public_ip)

    echo ""
    log_info "📋 Deployment Summary:"
    echo "  🌐 OpenLIT UI:     http://$INSTANCE_IP:3000"
    echo "  🔗 OTEL GRPC:     http://$INSTANCE_IP:4317"
    echo "  🔗 OTEL HTTP:     http://$INSTANCE_IP:4318"
    echo "  🖥️  SSH Access:    $(terraform output -raw ssh_command)"
    echo ""
    log_info "📖 Next steps:"
    echo "  1. Open http://$INSTANCE_IP:3000 in your browser"
    echo "  2. Login with demo credentials from terraform.tfvars"
    echo "  3. Run health-check.sh to verify all services"
    echo ""
}

# Handle script arguments
case "${1:-deploy}" in
    "prerequisites"|"prereq")
        check_prerequisites
        ;;
    "build")
        build_and_push_image
        ;;
    "infrastructure"|"infra")
        deploy_infrastructure
        ;;
    "health")
        health_check
        ;;
    "deploy"|"")
        main
        ;;
    *)
        echo "Usage: $0 [prerequisites|build|infrastructure|health|deploy]"
        echo ""
        echo "  prerequisites  - Check prerequisites only"
        echo "  build         - Build and push Docker image only"
        echo "  infrastructure - Deploy Terraform infrastructure only"
        echo "  health        - Run health checks only"
        echo "  deploy        - Full deployment (default)"
        exit 1
        ;;
esac
