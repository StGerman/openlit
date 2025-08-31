#!/bin/bash
set -e

# OpenLIT Docker Build and Push Script
# Builds ARM64 images for AWS Graviton instances

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../aws/demo"

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

# Get configuration from terraform.tfvars
get_config() {
    if [ ! -f "$TERRAFORM_DIR/terraform.tfvars" ]; then
        log_error "terraform.tfvars not found. Copy from terraform.tfvars.example and configure."
        exit 1
    fi

    AWS_ACCOUNT_ID=$(grep '^aws_account_id' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
    AWS_REGION=$(grep '^aws_region' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
    ECR_REPOSITORY=$(grep '^ecr_repository' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)
    IMAGE_TAG="${1:-$(grep '^image_tag' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)}"

    log_info "Configuration:"
    echo "  AWS Account:   $AWS_ACCOUNT_ID"
    echo "  AWS Region:    $AWS_REGION"
    echo "  ECR Repo:      $ECR_REPOSITORY"
    echo "  Image Tag:     $IMAGE_TAG"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking build prerequisites..."

    # Check Docker and buildx
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
    fi

    if ! docker buildx version &> /dev/null; then
        log_error "Docker buildx is not available"
        exit 1
    fi

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed"
        exit 1
    fi

    # Check AWS authentication
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS CLI not configured. Run 'aws configure' first."
        exit 1
    fi

    log_success "All build prerequisites met"
}

# Create ECR repository if needed
setup_ecr_repository() {
    log_info "Setting up ECR repository..."

    # Check if repository exists
    if aws ecr describe-repositories --repository-names "$ECR_REPOSITORY" --region "$AWS_REGION" &> /dev/null; then
        log_success "ECR repository '$ECR_REPOSITORY' already exists"
    else
        log_info "Creating ECR repository '$ECR_REPOSITORY'..."
        aws ecr create-repository \
            --repository-name "$ECR_REPOSITORY" \
            --region "$AWS_REGION" \
            --image-scanning-configuration scanOnPush=true
        log_success "ECR repository created"
    fi

    # Login to ECR
    log_info "Logging into ECR..."
    aws ecr get-login-password --region "$AWS_REGION" | \
        docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

    log_success "ECR authentication successful"
}

# Build OpenLIT image
build_openlit_image() {
    log_info "Building OpenLIT image for ARM64..."

    cd "$PROJECT_ROOT"

    # Full image name
    FULL_IMAGE_NAME="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG"

    log_info "Building image: $FULL_IMAGE_NAME"

    # Build ARM64 image for Graviton instances
    docker buildx build \
        --platform linux/arm64 \
        --file src/client/Dockerfile \
        --tag "$FULL_IMAGE_NAME" \
        --push \
        src/client/

    log_success "OpenLIT image built and pushed successfully"
    log_info "Image: $FULL_IMAGE_NAME"
}

# Build OTEL Collector image (if needed)
build_otel_image() {
    log_info "Checking OTEL Collector image..."

    # For now, we're using the official image
    # In the future, we might need a custom collector
    log_info "Using official OTEL Collector image: otel/opentelemetry-collector-contrib:0.94.0"

    # Pre-pull the ARM64 version to verify it's available
    docker pull --platform linux/arm64 otel/opentelemetry-collector-contrib:0.94.0
    log_success "OTEL Collector image verified"
}

# Test local build
test_local_build() {
    log_info "Testing local build..."

    cd "$PROJECT_ROOT"

    # Build local test image
    docker buildx build \
        --platform linux/arm64 \
        --file src/client/Dockerfile \
        --tag "openlit-test:$IMAGE_TAG" \
        --load \
        src/client/

    log_success "Local test build completed"

    # Test that the image starts
    log_info "Testing image startup..."
    CONTAINER_ID=$(docker run -d -p 3001:3000 "openlit-test:$IMAGE_TAG")
    sleep 10

    if curl -f -s "http://localhost:3001/" &> /dev/null; then
        log_success "Test container started successfully"
    else
        log_warning "Test container may not be fully ready"
    fi

    # Cleanup test container
    docker stop "$CONTAINER_ID" &> /dev/null
    docker rm "$CONTAINER_ID" &> /dev/null
    log_info "Test container cleaned up"
}

# Main build function
main() {
    IMAGE_TAG="${1:-latest}"

    log_info "🏗️  OpenLIT Docker Build and Push"
    log_info "=================================="

    get_config "$IMAGE_TAG"
    check_prerequisites
    setup_ecr_repository
    build_openlit_image
    build_otel_image

    log_success "🎉 Build and push completed successfully!"

    echo ""
    log_info "📋 Build Summary:"
    echo "  🐳 Image: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:$IMAGE_TAG"
    echo "  🏗️  Platform: linux/arm64 (Graviton optimized)"
    echo "  📍 Registry: AWS ECR ($AWS_REGION)"
    echo ""
    log_info "💡 Next steps:"
    echo "  1. Update terraform.tfvars with image_tag = \"$IMAGE_TAG\" if needed"
    echo "  2. Run deploy.sh to deploy with this image"
}

# Handle script arguments
case "${1:-build}" in
    "test")
        IMAGE_TAG="${2:-latest}"
        get_config "$IMAGE_TAG"
        check_prerequisites
        test_local_build
        ;;
    "build"|"")
        main "${2:-latest}"
        ;;
    *)
        echo "Usage: $0 [build|test] [image_tag]"
        echo ""
        echo "  build [tag]  - Build and push to ECR (default tag: latest)"
        echo "  test [tag]   - Build and test locally only"
        echo ""
        echo "Examples:"
        echo "  $0 build latest"
        echo "  $0 build dev-$(date +%Y%m%d)"
        echo "  $0 test"
        exit 1
        ;;
esac
