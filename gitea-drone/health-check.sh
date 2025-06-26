#!/bin/bash

# Health Check Script for Gitea + Drone CI/CD Platform
# This script checks the health of all services

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check HTTP endpoint
check_http_endpoint() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}

    print_color $YELLOW "Checking $name at $url..."

    if command -v curl >/dev/null 2>&1; then
        if response=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url" 2>/dev/null); then
            if [ "$response" -eq "$expected_code" ]; then
                print_color $GREEN "  ✓ $name is healthy (HTTP $response)"
                return 0
            else
                print_color $RED "  ✗ $name returned HTTP $response (expected $expected_code)"
                return 1
            fi
        else
            print_color $RED "  ✗ $name is not accessible"
            return 1
        fi
    else
        print_color $YELLOW "  ⚠ curl not available, skipping HTTP check for $name"
        return 0
    fi
}

# Function to check container status
check_container_status() {
    local container_name=$1

    if command -v docker >/dev/null 2>&1; then
        if docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "^$container_name"; then
            local status=$(docker ps --format "{{.Status}}" --filter "name=$container_name")
            if [[ "$status" == *"healthy"* ]] || [[ "$status" == *"Up"* ]]; then
                print_color $GREEN "  ✓ Container $container_name is running: $status"
                return 0
            else
                print_color $RED "  ✗ Container $container_name status: $status"
                return 1
            fi
        else
            print_color $RED "  ✗ Container $container_name is not running"
            return 1
        fi
    else
        print_color $YELLOW "  ⚠ Docker not available, skipping container check"
        return 0
    fi
}

print_color $BLUE "=== Health Check for Gitea + Drone CI/CD Platform ==="
echo

# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    print_color $YELLOW "Loading configuration from .env file..."
    while IFS= read -r line || [ -n "$line" ]; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
            continue
        fi

        # Export the variable if it's in KEY=VALUE format
        if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
            export "$line"
        fi
    done < ".env"
fi

# Set defaults
IP_ADDRESS=${IP_ADDRESS:-localhost}
GITEA_DOMAIN=${GITEA_DOMAIN:-$IP_ADDRESS}
DRONE_DOMAIN=${DRONE_DOMAIN:-$IP_ADDRESS}

print_color $BLUE "Configuration:"
print_color $BLUE "  IP_ADDRESS: $IP_ADDRESS"
print_color $BLUE "  GITEA_DOMAIN: $GITEA_DOMAIN"
print_color $BLUE "  DRONE_DOMAIN: $DRONE_DOMAIN"
echo

# Check Docker Compose services
print_color $YELLOW "=== Checking Docker Containers ==="
check_container_status "gitea-nginx"
check_container_status "gitea"
check_container_status "drone"
check_container_status "drone-runner"
echo

# Check direct service endpoints
print_color $YELLOW "=== Checking Direct Service Endpoints ==="
check_http_endpoint "Gitea (Direct)" "http://$IP_ADDRESS:3000/api/healthz"
check_http_endpoint "Drone (Direct)" "http://$IP_ADDRESS:3001/healthz"
check_http_endpoint "Drone Runner" "http://$IP_ADDRESS:3002/healthz"
echo

# Check Nginx proxy endpoints
print_color $YELLOW "=== Checking Nginx Proxy Endpoints ==="
check_http_endpoint "Nginx Health Check" "http://$IP_ADDRESS/health"

# Only check domain endpoints if they're different from IP
if [ "$GITEA_DOMAIN" != "$IP_ADDRESS" ]; then
    check_http_endpoint "Gitea (HTTP via Nginx)" "http://$GITEA_DOMAIN/health" "301"
    check_http_endpoint "Gitea (HTTPS via Nginx)" "https://$GITEA_DOMAIN/api/healthz" "200"
fi

if [ "$DRONE_DOMAIN" != "$IP_ADDRESS" ] && [ "$DRONE_DOMAIN" != "${IP_ADDRESS}:3001" ]; then
    check_http_endpoint "Drone (HTTP via Nginx)" "http://$DRONE_DOMAIN/health" "301"
    check_http_endpoint "Drone (HTTPS via Nginx)" "https://$DRONE_DOMAIN/healthz" "200"
fi
echo

# Check SSL certificates
print_color $YELLOW "=== Checking SSL Certificates ==="
if [ -f "data/ssl/${GITEA_DOMAIN}.crt" ]; then
    cert_info=$(openssl x509 -in "data/ssl/${GITEA_DOMAIN}.crt" -noout -dates 2>/dev/null || echo "Invalid certificate")
    if [[ "$cert_info" != "Invalid certificate" ]]; then
        print_color $GREEN "  ✓ Gitea SSL certificate exists and is valid"
        echo "    $cert_info"
    else
        print_color $RED "  ✗ Gitea SSL certificate is invalid"
    fi
else
    print_color $RED "  ✗ Gitea SSL certificate not found: data/ssl/${GITEA_DOMAIN}.crt"
fi

if [ -f "data/ssl/${DRONE_DOMAIN}.crt" ]; then
    cert_info=$(openssl x509 -in "data/ssl/${DRONE_DOMAIN}.crt" -noout -dates 2>/dev/null || echo "Invalid certificate")
    if [[ "$cert_info" != "Invalid certificate" ]]; then
        print_color $GREEN "  ✓ Drone SSL certificate exists and is valid"
        echo "    $cert_info"
    else
        print_color $RED "  ✗ Drone SSL certificate is invalid"
    fi
else
    print_color $RED "  ✗ Drone SSL certificate not found: data/ssl/${DRONE_DOMAIN}.crt"
fi
echo

# Check ports
print_color $YELLOW "=== Checking Port Availability ==="
for port in 80 443 2222 3000 3001 3002 9000; do
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln 2>/dev/null | grep -q ":$port "; then
            print_color $GREEN "  ✓ Port $port is in use"
        else
            print_color $RED "  ✗ Port $port is not in use"
        fi
    elif command -v ss >/dev/null 2>&1; then
        if ss -tuln 2>/dev/null | grep -q ":$port "; then
            print_color $GREEN "  ✓ Port $port is in use"
        else
            print_color $RED "  ✗ Port $port is not in use"
        fi
    else
        print_color $YELLOW "  ⚠ Cannot check port $port (netstat/ss not available)"
    fi
done
echo

print_color $BLUE "=== Health Check Complete ==="
print_color $YELLOW "For detailed logs, run: docker-compose logs -f [service_name]"