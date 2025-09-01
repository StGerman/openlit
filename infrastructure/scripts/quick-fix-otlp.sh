#!/bin/bash
set -e

# Quick fix script for OTLP collector issue
# This script updates the docker-compose configuration on the AWS instance

INSTANCE_IP="34.225.86.252"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

main() {
    log_info "🔧 Fixing OTLP Collector on AWS Instance"
    log_info "======================================="
    
    # Check current container status
    log_info "Current container status:"
    ssh ec2-user@$INSTANCE_IP 'sudo docker ps --format "table {{.Names}}\t{{.Status}}"'
    
    echo ""
    log_info "Checking OTEL collector logs for errors..."
    ssh ec2-user@$INSTANCE_IP 'sudo docker logs openlit-otel-collector-1 --tail 10' || log_warning "Could not get logs"
    
    echo ""
    log_info "Updating docker-compose configuration..."
    
    # Copy the updated docker-compose.yml to the instance
    scp /Users/sgerman/Code/openlit/docker-compose.yml ec2-user@$INSTANCE_IP:~/openlit/
    
    # Copy the otel collector config
    scp /Users/sgerman/Code/openlit/assets/otel-collector-config.yaml ec2-user@$INSTANCE_IP:~/openlit/assets/
    
    log_info "Restarting services with updated configuration..."
    
    # Restart the services
    ssh ec2-user@$INSTANCE_IP 'cd ~/openlit && sudo docker-compose down && sudo docker-compose up -d'
    
    log_info "Waiting for services to stabilize..."
    sleep 15
    
    # Check final status
    log_info "Final container status:"
    ssh ec2-user@$INSTANCE_IP 'sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
    
    echo ""
    log_info "Testing OTLP endpoints..."
    
    # Test ports
    if timeout 5 nc -z $INSTANCE_IP 4317; then
        log_success "OTLP GRPC port (4317) is now accessible!"
    else
        log_warning "OTLP GRPC port (4317) still not accessible"
    fi
    
    if timeout 5 nc -z $INSTANCE_IP 4318; then
        log_success "OTLP HTTP port (4318) is now accessible!"
    else
        log_warning "OTLP HTTP port (4318) still not accessible"
    fi
    
    # Test metrics endpoint
    if curl -f -s -m 10 "http://$INSTANCE_IP:8888/" > /dev/null; then
        log_success "OTLP collector metrics endpoint is responding"
    else
        log_warning "OTLP collector metrics endpoint not responding"
    fi
    
    echo ""
    log_success "🎉 Fix process completed!"
    log_info "Your FastAPI application should now be able to send telemetry to:"
    echo "  GRPC: http://$INSTANCE_IP:4317"
    echo "  HTTP: http://$INSTANCE_IP:4318"
}

main "$@"
