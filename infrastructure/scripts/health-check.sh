#!/bin/bash
set -e

# OpenLIT Health Check Script
# Validates that all services are running correctly

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

# Get instance information
get_instance_info() {
    cd "$TERRAFORM_DIR"

    if [ ! -f "terraform.tfstate" ]; then
        log_error "No Terraform state found. Run deploy.sh first."
        exit 1
    fi

    INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null)
    INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null)

    if [ -z "$INSTANCE_IP" ]; then
        log_error "Could not get instance IP from Terraform output"
        exit 1
    fi

    log_info "Instance IP: $INSTANCE_IP"
    log_info "Instance ID: $INSTANCE_ID"
}

# Check AWS instance status
check_aws_instance() {
    log_info "Checking AWS instance status..."

    INSTANCE_STATE=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].State.Name' \
        --output text)

    if [ "$INSTANCE_STATE" = "running" ]; then
        log_success "EC2 instance is running"
    else
        log_error "EC2 instance state: $INSTANCE_STATE"
        return 1
    fi
}

# Check OpenLIT UI
check_openlit_ui() {
    log_info "Checking OpenLIT UI..."

    for i in {1..5}; do
        if curl -f -s -m 10 "http://$INSTANCE_IP:3000/api/health" &> /dev/null; then
            log_success "OpenLIT UI is responding"

            # Check if we can get the main page
            if curl -f -s -m 10 "http://$INSTANCE_IP:3000" | grep -q "OpenLIT" 2>/dev/null; then
                log_success "OpenLIT UI main page accessible"
            else
                log_warning "OpenLIT UI responding but main page may have issues"
            fi
            return 0
        fi

        if [ $i -eq 5 ]; then
            log_error "OpenLIT UI not responding after 5 attempts"
            return 1
        fi

        log_info "Attempt $i/5: OpenLIT UI not ready, waiting 10 seconds..."
        sleep 10
    done
}

# Check OTEL Collector
check_otel_collector() {
    log_info "Checking OTEL Collector..."

    # Check metrics endpoint
    if curl -f -s -m 10 "http://$INSTANCE_IP:8888/" &> /dev/null; then
        log_success "OTEL Collector metrics endpoint responding"
    else
        log_warning "OTEL Collector metrics endpoint not responding"
    fi

    # Check GRPC endpoint (basic connection test)
    if timeout 5 nc -z "$INSTANCE_IP" 4317 2>/dev/null; then
        log_success "OTEL GRPC endpoint (4317) is accessible"
    else
        log_warning "OTEL GRPC endpoint (4317) not accessible"
    fi

    # Check HTTP endpoint
    if timeout 5 nc -z "$INSTANCE_IP" 4318 2>/dev/null; then
        log_success "OTEL HTTP endpoint (4318) is accessible"
    else
        log_warning "OTEL HTTP endpoint (4318) not accessible"
    fi
}

# Check ClickHouse connectivity
check_clickhouse_connectivity() {
    log_info "Checking ClickHouse connectivity from instance..."

    # Get ClickHouse config from terraform.tfvars
    cd "$TERRAFORM_DIR"
    CLICKHOUSE_HOST=$(grep '^clickhouse_host' terraform.tfvars | cut -d'"' -f2)

    if [ -n "$CLICKHOUSE_HOST" ]; then
        log_info "Testing connection to: $CLICKHOUSE_HOST"

        # Test basic connectivity
        if curl -f -s -m 10 "$CLICKHOUSE_HOST" &> /dev/null; then
            log_success "ClickHouse host is reachable"
        else
            log_warning "ClickHouse host connectivity test failed (may be expected for HTTPS endpoints)"
        fi
    else
        log_warning "Could not extract ClickHouse host from terraform.tfvars"
    fi
}

# Check Docker services on instance
check_docker_services() {
    log_info "Checking Docker services on instance..."

    # SSH into instance and check Docker status
    KEY_PAIR_NAME=$(grep '^key_pair_name' "$TERRAFORM_DIR/terraform.tfvars" | cut -d'"' -f2)

    if [ -f "$HOME/.ssh/${KEY_PAIR_NAME}.pem" ]; then
        SSH_CMD="ssh -i $HOME/.ssh/${KEY_PAIR_NAME}.pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP"

        log_info "Connecting via SSH to check Docker services..."

        # Check if Docker is running
        if $SSH_CMD "sudo systemctl is-active docker" &> /dev/null; then
            log_success "Docker service is running"
        else
            log_error "Docker service is not running"
            return 1
        fi

        # Check OpenLIT containers
        CONTAINERS=$($SSH_CMD "cd /home/ec2-user/openlit && docker-compose ps --services" 2>/dev/null || echo "")

        if [ -n "$CONTAINERS" ]; then
            log_success "Docker Compose services found: $CONTAINERS"

            # Check container status
            $SSH_CMD "cd /home/ec2-user/openlit && docker-compose ps" || log_warning "Could not get container status"
        else
            log_warning "Docker Compose services not found or not accessible"
        fi

    else
        log_warning "SSH key not found at $HOME/.ssh/${KEY_PAIR_NAME}.pem - skipping Docker service check"
    fi
}

# Print deployment information
print_deployment_info() {
    log_info "📋 Deployment Information"
    echo "=============================="

    cd "$TERRAFORM_DIR"

    echo "🌐 OpenLIT UI:        http://$INSTANCE_IP:3000"
    echo "🔗 OTEL GRPC:        http://$INSTANCE_IP:4317"
    echo "🔗 OTEL HTTP:        http://$INSTANCE_IP:4318"
    echo "📊 OTEL Metrics:     http://$INSTANCE_IP:8888"
    echo "🖥️  SSH Access:       $(terraform output -raw ssh_command 2>/dev/null || echo "ssh -i your-key.pem ec2-user@$INSTANCE_IP")"
    echo ""

    # Show demo accounts if available
    DEMO_EMAILS=$(grep '^demo_emails' terraform.tfvars | cut -d'"' -f2 2>/dev/null || echo "")
    if [ -n "$DEMO_EMAILS" ]; then
        log_info "👤 Demo Accounts:"
        echo "   Email: $(echo $DEMO_EMAILS | cut -d',' -f1)"
        echo "   (Password from terraform.tfvars)"
    fi
}

# Main health check function
main() {
    log_info "🏥 OpenLIT Health Check"
    log_info "======================="

    get_instance_info
    check_aws_instance
    check_openlit_ui
    check_otel_collector
    check_clickhouse_connectivity
    check_docker_services

    echo ""
    log_success "🎉 Health check completed!"
    print_deployment_info
}

# Handle script arguments
case "${1:-check}" in
    "aws")
        get_instance_info
        check_aws_instance
        ;;
    "ui")
        get_instance_info
        check_openlit_ui
        ;;
    "otel")
        get_instance_info
        check_otel_collector
        ;;
    "clickhouse")
        get_instance_info
        check_clickhouse_connectivity
        ;;
    "docker")
        get_instance_info
        check_docker_services
        ;;
    "info")
        get_instance_info
        print_deployment_info
        ;;
    "check"|"")
        main
        ;;
    *)
        echo "Usage: $0 [aws|ui|otel|clickhouse|docker|info|check]"
        echo ""
        echo "  aws        - Check AWS instance status only"
        echo "  ui         - Check OpenLIT UI only"
        echo "  otel       - Check OTEL Collector only"
        echo "  clickhouse - Check ClickHouse connectivity only"
        echo "  docker     - Check Docker services only"
        echo "  info       - Show deployment information only"
        echo "  check      - Run all health checks (default)"
        exit 1
        ;;
esac
