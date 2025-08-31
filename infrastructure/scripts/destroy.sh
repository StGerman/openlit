#!/bin/bash
set -e

# OpenLIT AWS EC2 Destroy Script
# This script safely destroys the deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# Confirm destruction
confirm_destroy() {
    log_warning "🚨 This will destroy the OpenLIT deployment and all associated resources!"

    cd "$TERRAFORM_DIR"

    if [ -f "terraform.tfstate" ]; then
        log_info "Current deployment resources:"
        terraform show -json | jq -r '.values.root_module.resources[]?.values.tags.Name // empty' 2>/dev/null | sort -u || echo "  (Unable to list resources)"
    fi

    echo ""
    read -p "Are you sure you want to destroy the deployment? [yes/no]: " confirm

    if [ "$confirm" != "yes" ]; then
        log_info "Destruction cancelled"
        exit 0
    fi
}

# Destroy infrastructure
destroy_infrastructure() {
    log_info "Destroying infrastructure with Terraform..."

    cd "$TERRAFORM_DIR"

    if [ ! -f "terraform.tfstate" ]; then
        log_warning "No Terraform state found - nothing to destroy"
        return 0
    fi

    # Plan destruction
    terraform plan -destroy -var-file="terraform.tfvars" -out="destroy-plan"

    # Apply destruction
    log_info "Applying destruction plan..."
    terraform apply "destroy-plan"

    # Clean up plan files
    rm -f tfplan destroy-plan

    log_success "Infrastructure destroyed successfully"
}

# Clean up ECR images (optional)
cleanup_ecr_images() {
    log_info "Checking ECR repository for cleanup..."

    cd "$TERRAFORM_DIR"

    if [ ! -f "terraform.tfvars" ]; then
        log_warning "terraform.tfvars not found - skipping ECR cleanup"
        return 0
    fi

    AWS_REGION=$(grep '^aws_region' terraform.tfvars | cut -d'"' -f2)
    ECR_REPOSITORY=$(grep '^ecr_repository' terraform.tfvars | cut -d'"' -f2)

    # Check if ECR repository exists
    if aws ecr describe-repositories --repository-names "$ECR_REPOSITORY" --region "$AWS_REGION" &> /dev/null; then
        echo ""
        read -p "Do you want to delete ECR repository '$ECR_REPOSITORY' and all images? [yes/no]: " confirm_ecr

        if [ "$confirm_ecr" = "yes" ]; then
            log_info "Deleting ECR repository..."
            aws ecr delete-repository --repository-name "$ECR_REPOSITORY" --region "$AWS_REGION" --force
            log_success "ECR repository deleted"
        else
            log_info "ECR repository preserved"
        fi
    else
        log_info "ECR repository not found or already deleted"
    fi
}

# Main destroy function
main() {
    log_info "🗑️  OpenLIT AWS EC2 Destruction"
    log_info "==============================="

    confirm_destroy
    destroy_infrastructure
    cleanup_ecr_images

    log_success "🎉 Destruction completed successfully!"
    echo ""
    log_info "📋 Cleanup Summary:"
    echo "  ✅ EC2 instance terminated"
    echo "  ✅ Elastic IP released"
    echo "  ✅ Security groups removed"
    echo "  ✅ IAM roles and policies deleted"
    echo ""
    log_info "💡 Note: Local files and configurations are preserved"
}

# Handle script arguments
case "${1:-destroy}" in
    "confirm")
        confirm_destroy
        ;;
    "infrastructure"|"infra")
        destroy_infrastructure
        ;;
    "ecr")
        cleanup_ecr_images
        ;;
    "destroy"|"")
        main
        ;;
    *)
        echo "Usage: $0 [confirm|infrastructure|ecr|destroy]"
        echo ""
        echo "  confirm        - Show destruction confirmation only"
        echo "  infrastructure - Destroy Terraform infrastructure only"
        echo "  ecr           - Clean up ECR repository only"
        echo "  destroy       - Full destruction (default)"
        exit 1
        ;;
esac
