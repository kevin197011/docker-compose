#!/bin/bash

# Rancher Docker Compose Deployment Script
# This script initializes the Rancher environment with auto-generated passwords

set -e

COMPOSE_FILE="compose.yml"
LOCK_FILE=".rancher_initialized"
MYSQL_CONFIG="config/mysql/my.cnf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-16
}

# Function to update password in compose file
update_compose_password() {
    local key=$1
    local password=$2

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|${key}:-[^}]*|${key}:-${password}|g" "$COMPOSE_FILE"
    else
        # Linux
        sed -i "s|${key}:-[^}]*|${key}:-${password}|g" "$COMPOSE_FILE"
    fi
}

# Function to regenerate passwords only
regenerate_passwords() {
    print_info "Regenerating passwords..."

    # Generate new passwords
    MYSQL_ROOT_PASSWORD=$(generate_password)
    MYSQL_PASSWORD=$(generate_password)
    CATTLE_BOOTSTRAP_PASSWORD=$(generate_password)

    # Update compose file
    update_compose_password "MYSQL_ROOT_PASSWORD" "$MYSQL_ROOT_PASSWORD"
    update_compose_password "MYSQL_PASSWORD" "$MYSQL_PASSWORD"
    update_compose_password "CATTLE_BOOTSTRAP_PASSWORD" "$CATTLE_BOOTSTRAP_PASSWORD"

    print_success "Passwords regenerated successfully!"

    # Display new passwords
    echo ""
    echo "==================== Rancher Credentials ===================="
    echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD"
    echo "MySQL User Password: $MYSQL_PASSWORD"
    echo "Rancher Admin Password: $CATTLE_BOOTSTRAP_PASSWORD"
    echo "=============================================================="
    echo ""

    exit 0
}

# Check for regenerate flag
if [[ "$1" == "--regenerate-secrets" ]]; then
    regenerate_passwords
fi

# Check if already initialized
if [[ -f "$LOCK_FILE" ]]; then
    print_warning "Rancher environment is already initialized."
    print_info "If you want to regenerate passwords only, run: $0 --regenerate-secrets"
    print_info "To reinitialize completely, remove the lock file: rm $LOCK_FILE"
    exit 0
fi

print_info "Initializing Rancher deployment environment..."

# Check if docker compose is available
if ! command -v docker compose &> /dev/null && ! command -v docker &> /dev/null; then
    print_error "Docker and docker compose are required but not installed."
    exit 1
fi

# Create config and data directories if they don't exist
mkdir -p config/mysql
mkdir -p data/{mysql,rancher,audit_log,certs}

# Generate random passwords
print_info "Generating secure passwords..."
MYSQL_ROOT_PASSWORD=$(generate_password)
MYSQL_PASSWORD=$(generate_password)
CATTLE_BOOTSTRAP_PASSWORD=$(generate_password)

# Update passwords in compose file
print_info "Updating configuration files..."
update_compose_password "MYSQL_ROOT_PASSWORD" "$MYSQL_ROOT_PASSWORD"
update_compose_password "MYSQL_PASSWORD" "$MYSQL_PASSWORD"
update_compose_password "CATTLE_BOOTSTRAP_PASSWORD" "$CATTLE_BOOTSTRAP_PASSWORD"

# Create lock file
touch "$LOCK_FILE"

print_success "Rancher environment initialized successfully!"

# Display important information
echo ""
echo "==================== Rancher Deployment Info ===================="
echo "HTTPS Access: https://your-server-ip:9443"
echo "HTTP Access: http://your-server-ip:9080"
echo ""
echo "==================== Initial Credentials ===================="
echo "MySQL Root Password: $MYSQL_ROOT_PASSWORD"
echo "MySQL User Password: $MYSQL_PASSWORD"
echo "Rancher Admin Password: $CATTLE_BOOTSTRAP_PASSWORD"
echo ""
echo "==================== First Time Setup ===================="
echo "1. Start services: docker compose up -d"
echo "2. Wait for Rancher to initialize (may take 2-3 minutes)"
echo "3. Access Rancher web interface"
echo "4. Login with username 'admin' and the password above"
echo "5. Configure your Kubernetes clusters"
echo ""
echo "==================== Useful Commands ===================="
echo "View logs: docker compose logs -f rancher-server"
echo "Restart services: docker compose restart"
echo "Stop services: docker compose down"
echo "Update images: docker compose pull && docker compose up -d"
echo "=============================================================="
echo ""

print_warning "Please save these credentials securely!"
print_info "You can regenerate passwords anytime with: $0 --regenerate-secrets"