#!/bin/bash

# Gitea + Drone CI/CD Platform with Nginx Reverse Proxy
# This script sets up a complete CI/CD environment with SSL support

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

# Function to load environment variables from .env file
load_env_file() {
    local env_file=".env"

    if [ -f "$env_file" ]; then
        print_color $YELLOW "Loading configuration from $env_file..."

        # Load variables from .env file, ignoring comments and empty lines
        while IFS= read -r line || [ -n "$line" ]; do
            # Skip comments and empty lines
            if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line// }" ]]; then
                continue
            fi

            # Export the variable if it's in KEY=VALUE format
            if [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
                export "$line"
                print_color $GREEN "  ✓ Loaded: ${line%%=*}"
            fi
        done < "$env_file"

        print_color $GREEN "✓ Configuration loaded from $env_file"
    else
        print_color $YELLOW "No .env file found, using environment variables or defaults"
    fi
}

# Function to create .env template if it doesn't exist
create_env_template() {
    local env_file=".env"

    if [ ! -f "$env_file" ]; then
        print_color $YELLOW "Creating .env template file..."

                 cat > "$env_file" << 'EOF'
# Gitea + Drone CI/CD Configuration
# Copy this file and modify the values according to your environment

# Network Configuration
IP_ADDRESS=your-server-ip

# Domain Configuration
GITEA_DOMAIN=git.example.com
DRONE_DOMAIN=drone.example.com

# Service Versions
NGINX_VERSION=1.25-alpine
GITEA_VERSION=1.21.5
DRONE_VERSION=2.23.0
DRONE_RUNNER_VERSION=1.8.3

# Drone Configuration (will be auto-generated if not set)
DRONE_RPC_SECRET=
DRONE_GITEA_CLIENT_ID=
DRONE_GITEA_CLIENT_SECRET=
DRONE_USER_CREATE=

# Gitea Configuration
GITEA_ADMIN_USER=root

# SSL Configuration
SSL_COUNTRY=US
SSL_STATE=State
SSL_CITY=City
SSL_ORGANIZATION=Organization
SSL_ORG_UNIT=OrgUnit

# Certificate Names (optional, defaults to domain names)
GITEA_CERT_NAME=git.example.com
DRONE_CERT_NAME=drone.example.com
EOF

        print_color $GREEN "✓ Created .env template file"
        print_color $YELLOW "Please edit .env file with your configuration before running again"
        exit 0
    fi
}

print_color $BLUE "=== Gitea + Drone CI/CD Platform Setup with Nginx ==="
echo

# Parse command line arguments
case "${1:-}" in
    --create-env)
        create_env_template
        exit 0
        ;;
    --help|-h)
        print_color $BLUE "Usage: $0 [OPTIONS]"
        echo
        print_color $YELLOW "Options:"
        echo "  --create-env    Create .env template file"
        echo "  --help, -h      Show this help message"
        echo
                 print_color $YELLOW "Environment Variables (can be set in .env file):"
         echo "  IP_ADDRESS               Server IP address (required)"
         echo "  GITEA_DOMAIN             Gitea domain name (optional, defaults to IP_ADDRESS)"
         echo "  DRONE_DOMAIN             Drone domain name (optional, defaults to IP_ADDRESS:3001)"
         echo "  GITEA_CERT_NAME          Gitea SSL certificate name (defaults to GITEA_DOMAIN)"
         echo "  DRONE_CERT_NAME          Drone SSL certificate name (defaults to DRONE_DOMAIN)"
         echo "  NGINX_VERSION            Nginx version (default: 1.25-alpine)"
         echo "  GITEA_VERSION            Gitea version (default: 1.21.5)"
         echo "  DRONE_VERSION            Drone version (default: 2.23.0)"
         echo "  DRONE_RUNNER_VERSION     Drone Runner version (default: 1.8.3)"
         echo "  DRONE_RPC_SECRET         Drone RPC secret (auto-generated if empty)"
         echo "  DRONE_GITEA_CLIENT_ID    Gitea OAuth2 Client ID"
         echo "  DRONE_GITEA_CLIENT_SECRET Gitea OAuth2 Client Secret"
         echo "  DRONE_USER_CREATE        Drone user creation string"
         echo "  GITEA_ADMIN_USER         Gitea admin username (default: root)"
        exit 0
        ;;
esac

# Load configuration from .env file
load_env_file

# Create necessary directories
print_color $YELLOW "Creating directory structure..."
mkdir -p data/{gitea,drone,nginx/logs,nginx/cache,ssl}
mkdir -p config/nginx/conf.d

print_color $GREEN "✓ Directory structure created"

# Check for required environment variables
print_color $YELLOW "Checking environment variables..."

if [ -z "$IP_ADDRESS" ]; then
    print_color $RED "ERROR: IP_ADDRESS environment variable is not set"
    echo "Please set it in .env file or environment: IP_ADDRESS=your_server_ip"
    echo "Run '$0 --create-env' to create a template .env file"
    exit 1
fi

if [ -z "$GITEA_DOMAIN" ]; then
    print_color $YELLOW "GITEA_DOMAIN not set, using IP_ADDRESS for configuration"
    export GITEA_DOMAIN=$IP_ADDRESS
fi

if [ -z "$DRONE_DOMAIN" ]; then
    print_color $YELLOW "DRONE_DOMAIN not set, using IP_ADDRESS:3001 for configuration"
    export DRONE_DOMAIN="${IP_ADDRESS}:3001"
fi

# Set default versions if not provided
export NGINX_VERSION=${NGINX_VERSION:-1.25-alpine}
export GITEA_VERSION=${GITEA_VERSION:-1.21.5}
export DRONE_VERSION=${DRONE_VERSION:-2.23.0}
export DRONE_RUNNER_VERSION=${DRONE_RUNNER_VERSION:-1.8.3}
export GITEA_ADMIN_USER=${GITEA_ADMIN_USER:-root}

# Set certificate names if not provided
export GITEA_CERT_NAME=${GITEA_CERT_NAME:-$GITEA_DOMAIN}
export DRONE_CERT_NAME=${DRONE_CERT_NAME:-$DRONE_DOMAIN}

# Set SSL certificate defaults
export SSL_COUNTRY=${SSL_COUNTRY:-US}
export SSL_STATE=${SSL_STATE:-State}
export SSL_CITY=${SSL_CITY:-City}
export SSL_ORGANIZATION=${SSL_ORGANIZATION:-Organization}
export SSL_ORG_UNIT=${SSL_ORG_UNIT:-OrgUnit}

print_color $GREEN "✓ Environment variables configured"
print_color $BLUE "  IP_ADDRESS: $IP_ADDRESS"
print_color $BLUE "  GITEA_DOMAIN: $GITEA_DOMAIN"
print_color $BLUE "  DRONE_DOMAIN: $DRONE_DOMAIN"
print_color $BLUE "  GITEA_CERT_NAME: $GITEA_CERT_NAME"
print_color $BLUE "  DRONE_CERT_NAME: $DRONE_CERT_NAME"
print_color $BLUE "  Gitea Version: $GITEA_VERSION"
print_color $BLUE "  Drone Version: $DRONE_VERSION"

# Generate secrets if not provided
if [ -z "$DRONE_RPC_SECRET" ]; then
    export DRONE_RPC_SECRET=$(openssl rand -hex 16)
    print_color $YELLOW "Generated DRONE_RPC_SECRET: $DRONE_RPC_SECRET"

    # Update .env file with generated secret
    if [ -f ".env" ]; then
        if grep -q "^DRONE_RPC_SECRET=" .env; then
            sed -i.bak "s/^DRONE_RPC_SECRET=.*/DRONE_RPC_SECRET=$DRONE_RPC_SECRET/" .env
        else
            echo "DRONE_RPC_SECRET=$DRONE_RPC_SECRET" >> .env
        fi
        print_color $GREEN "✓ Updated DRONE_RPC_SECRET in .env file"
    fi
fi

if [ -z "$DRONE_GITEA_CLIENT_ID" ]; then
    print_color $YELLOW "DRONE_GITEA_CLIENT_ID not set - you'll need to configure this after Gitea setup"
fi

if [ -z "$DRONE_GITEA_CLIENT_SECRET" ]; then
    print_color $YELLOW "DRONE_GITEA_CLIENT_SECRET not set - you'll need to configure this after Gitea setup"
fi

# SSL Certificate setup
print_color $YELLOW "Setting up SSL certificates..."

# Create Gitea SSL certificate
if [ ! -f "data/ssl/${GITEA_CERT_NAME}.crt" ] || [ ! -f "data/ssl/${GITEA_CERT_NAME}.key" ]; then
    print_color $YELLOW "Gitea SSL certificates not found. Creating self-signed certificates..."

    # Create self-signed certificate for Gitea
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "data/ssl/${GITEA_CERT_NAME}.key" \
        -out "data/ssl/${GITEA_CERT_NAME}.crt" \
        -subj "/C=${SSL_COUNTRY}/ST=${SSL_STATE}/L=${SSL_CITY}/O=${SSL_ORGANIZATION}/OU=${SSL_ORG_UNIT}/CN=${GITEA_DOMAIN}"

    print_color $GREEN "✓ Gitea self-signed SSL certificate created"
else
    print_color $GREEN "✓ Gitea SSL certificates found"
fi

# Create Drone SSL certificate
if [ ! -f "data/ssl/${DRONE_CERT_NAME}.crt" ] || [ ! -f "data/ssl/${DRONE_CERT_NAME}.key" ]; then
    print_color $YELLOW "Drone SSL certificates not found. Creating self-signed certificates..."

    # Create self-signed certificate for Drone
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "data/ssl/${DRONE_CERT_NAME}.key" \
        -out "data/ssl/${DRONE_CERT_NAME}.crt" \
        -subj "/C=${SSL_COUNTRY}/ST=${SSL_STATE}/L=${SSL_CITY}/O=${SSL_ORGANIZATION}/OU=${SSL_ORG_UNIT}/CN=${DRONE_DOMAIN}"

    print_color $GREEN "✓ Drone self-signed SSL certificate created"
else
    print_color $GREEN "✓ Drone SSL certificates found"
fi

print_color $YELLOW "For production, replace with proper SSL certificates from Let's Encrypt or CA"

# Set proper permissions
chmod 600 data/ssl/*.key
chmod 644 data/ssl/*.crt

# Process nginx configuration templates
print_color $YELLOW "Configuring nginx..."

# Process Gitea configuration
sed -e "s/\${GITEA_DOMAIN}/${GITEA_DOMAIN}/g" \
    -e "s/\${GITEA_CERT_NAME}/${GITEA_CERT_NAME}/g" \
    config/nginx/conf.d/gitea.conf > config/nginx/conf.d/gitea.conf.tmp
mv config/nginx/conf.d/gitea.conf.tmp config/nginx/conf.d/gitea.conf

# Process Drone configuration
sed -e "s/\${DRONE_DOMAIN}/${DRONE_DOMAIN}/g" \
    -e "s/\${DRONE_CERT_NAME}/${DRONE_CERT_NAME}/g" \
    config/nginx/conf.d/drone.conf > config/nginx/conf.d/drone.conf.tmp
mv config/nginx/conf.d/drone.conf.tmp config/nginx/conf.d/drone.conf

print_color $GREEN "✓ Nginx configuration updated"

# Start services
print_color $YELLOW "Starting services..."
docker-compose up -d

print_color $GREEN "✓ Services started successfully!"

echo
print_color $BLUE "=== Setup Complete ==="
print_color $GREEN "Access URLs:"
print_color $GREEN "  Gitea (HTTPS): https://${GITEA_DOMAIN}"
print_color $GREEN "  Gitea (HTTP):  http://${GITEA_DOMAIN} (redirects to HTTPS)"
print_color $GREEN "  Gitea (Direct): http://${IP_ADDRESS}:3000"
print_color $GREEN "  Drone (HTTPS): https://${DRONE_DOMAIN}"
print_color $GREEN "  Drone (HTTP):  http://${DRONE_DOMAIN} (redirects to HTTPS)"
print_color $GREEN "  Drone (Direct): http://${IP_ADDRESS}:3001"
print_color $GREEN "  Drone Runner UI: http://${IP_ADDRESS}:3002"
print_color $GREEN "  Gitea SSH: ${GITEA_DOMAIN}:2222"

echo
print_color $YELLOW "Next Steps:"
echo "1. Open Gitea at https://${GITEA_DOMAIN} and complete initial setup"
echo "2. Create OAuth2 application in Gitea:"
echo "   - Go to Settings > Applications > Manage OAuth2 Applications"
echo "   - Create new application with redirect URL: https://${DRONE_DOMAIN}/login"
echo "3. Update .env file with OAuth2 credentials:"
echo "   DRONE_GITEA_CLIENT_ID='your_client_id'"
echo "   DRONE_GITEA_CLIENT_SECRET='your_client_secret'"
echo "   DRONE_USER_CREATE='username:${GITEA_ADMIN_USER},admin:true'"
echo "4. Restart drone services: docker-compose restart drone drone-runner"

echo
print_color $YELLOW "Important Notes:"
echo "- Generated DRONE_RPC_SECRET: $DRONE_RPC_SECRET"
echo "- Self-signed certificates created for development:"
echo "  - Gitea: ${GITEA_CERT_NAME}.crt/.key"
echo "  - Drone: ${DRONE_CERT_NAME}.crt/.key"
echo "- For production, replace with proper SSL certificates"
echo "- SSH clone URL: git@${GITEA_DOMAIN}:username/repository.git (port 2222)"
echo "- Configuration saved in .env file"

echo
print_color $BLUE "For troubleshooting, check logs with:"
echo "docker-compose logs -f [service_name]"