#!/bin/bash
set -e

# OpenLIT Prerequisites Verification Script
# Validates all requirements for AWS EC2 deployment

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

ERRORS=0

check_tool() {
    local tool=$1
    local version_cmd=$2
    local min_version=$3

    if command -v "$tool" &> /dev/null; then
        local version=$($version_cmd 2>/dev/null | head -1)
        log_success "$tool: $version"
        return 0
    else
        log_error "$tool: Not installed"
        ((ERRORS++))
        return 1
    fi
}

check_aws_auth() {
    log_info "Checking AWS authentication..."

    if aws sts get-caller-identity &> /dev/null; then
        local account=$(aws sts get-caller-identity --query Account --output text)
        local user=$(aws sts get-caller-identity --query Arn --output text)
        log_success "AWS authenticated: $user (Account: $account)"
        return 0
    else
        log_error "AWS not authenticated. Run 'aws configure'"
        ((ERRORS++))
        return 1
    fi
}

check_aws_permissions() {
    log_info "Checking AWS permissions..."

    # Test EC2 permissions
    if aws ec2 describe-regions --region us-east-1 &> /dev/null; then
        log_success "EC2 permissions: OK"
    else
        log_error "EC2 permissions: Missing"
        ((ERRORS++))
    fi

    # Test ECR permissions
    if aws ecr describe-repositories --region us-east-1 &> /dev/null; then
        log_success "ECR permissions: OK"
    else
        log_warning "ECR permissions: May be missing (will be tested during deployment)"
    fi
}

check_ssh_key() {
    log_info "Checking SSH key configuration..."

    # Check if user has any key pairs
    local key_count=$(aws ec2 describe-key-pairs --region us-east-1 --query 'length(KeyPairs)' --output text 2>/dev/null || echo "0")

    if [ "$key_count" -gt 0 ]; then
        log_success "EC2 key pairs available: $key_count"
        log_info "Available key pairs:"
        aws ec2 describe-key-pairs --region us-east-1 --query 'KeyPairs[].KeyName' --output text | tr '\t' '\n' | sed 's/^/  - /'
    else
        log_error "No EC2 key pairs found. Create one in AWS Console or CLI."
        log_info "To create a key pair: aws ec2 create-key-pair --key-name openlit-demo --query 'KeyMaterial' --output text > openlit-demo.pem && chmod 400 openlit-demo.pem"
        ((ERRORS++))
    fi
}

check_docker() {
    log_info "Checking Docker configuration..."

    if check_tool "docker" "docker --version"; then
        # Check if Docker daemon is running
        if docker info &> /dev/null; then
            log_success "Docker daemon is running"

            # Check buildx
            if docker buildx version &> /dev/null; then
                log_success "Docker buildx available"
            else
                log_error "Docker buildx not available"
                ((ERRORS++))
            fi
        else
            log_error "Docker daemon not running. Start Docker Desktop."
            ((ERRORS++))
        fi
    fi
}

check_project_setup() {
    log_info "Checking project setup..."

    # Check if we're in the right directory
    if [ -f "../../README.md" ] && grep -q "OpenLIT" "../../README.md" 2>/dev/null; then
        log_success "OpenLIT project directory confirmed"
    else
        log_error "Not in OpenLIT project directory. Run from infrastructure/scripts/"
        ((ERRORS++))
    fi

    # Check terraform.tfvars
    if [ -f "../aws/demo/terraform.tfvars" ]; then
        log_success "terraform.tfvars exists"
    else
        log_warning "terraform.tfvars not found. Copy from terraform.tfvars.example"
        log_info "Run: cp ../aws/demo/terraform.tfvars.example ../aws/demo/terraform.tfvars"
    fi

    # Check client Dockerfile
    if [ -f "../../src/client/Dockerfile" ]; then
        log_success "OpenLIT client Dockerfile found"
    else
        log_error "OpenLIT client Dockerfile not found"
        ((ERRORS++))
    fi
}

check_network_connectivity() {
    log_info "Checking network connectivity..."

    # Test AWS API connectivity
    if curl -s -m 10 "https://ec2.us-east-1.amazonaws.com" &> /dev/null; then
        log_success "AWS API connectivity: OK"
    else
        log_warning "AWS API connectivity: May have issues"
    fi

    # Test Docker Hub connectivity
    if curl -s -m 10 "https://registry-1.docker.io" &> /dev/null; then
        log_success "Docker Hub connectivity: OK"
    else
        log_warning "Docker Hub connectivity: May have issues"
    fi
}

main() {
    log_info "🔍 OpenLIT AWS EC2 Prerequisites Verification"
    log_info "============================================="
    echo ""

    # Core tools
    log_info "🔧 Checking core tools..."
    check_tool "aws" "aws --version" "2.0"
    check_tool "terraform" "terraform --version" "1.0"
    check_tool "git" "git --version" "2.0"
    echo ""

    # Docker
    check_docker
    echo ""

    # AWS configuration
    check_aws_auth
    check_aws_permissions
    check_ssh_key
    echo ""

    # Project setup
    check_project_setup
    echo ""

    # Network
    check_network_connectivity
    echo ""

    # Summary
    if [ $ERRORS -eq 0 ]; then
        log_success "🎉 All prerequisites met! Ready for deployment."
        echo ""
        log_info "📋 Next steps:"
        echo "  1. Configure terraform.tfvars (if not done already)"
        echo "  2. Run ./deploy.sh to start deployment"
        echo "  3. Run ./health-check.sh to verify deployment"
        exit 0
    else
        log_error "🚨 $ERRORS error(s) found. Fix the issues above before deploying."
        echo ""
        log_info "📋 Common fixes:"
        echo "  - Install missing tools using Homebrew (macOS) or package manager"
        echo "  - Run 'aws configure' to set up AWS credentials"
        echo "  - Create EC2 key pair in AWS Console"
        echo "  - Start Docker Desktop"
        echo "  - Copy and configure terraform.tfvars.example"
        exit 1
    fi
}

main "$@"
