#!/bin/bash

# CentOS 9 Rancher 部署准备脚本
# 此脚本配置 CentOS 9 系统以支持 Rancher 运行

set -e

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

print_info "Preparing CentOS 9 system for Rancher deployment..."

# Update system
print_info "Updating system packages..."
dnf update -y

# Install required packages
print_info "Installing required packages..."
dnf install -y \
    container-tools \
    docker-compose \
    firewalld \
    iptables \
    curl \
    wget \
    tar \
    gzip

# Configure Docker/Podman
print_info "Configuring container runtime..."

# Enable and start Docker if available, otherwise use Podman
if command -v docker &> /dev/null; then
    systemctl enable --now docker
    print_success "Docker enabled and started"
else
    # Configure Podman for Docker compatibility
    systemctl enable --now podman.socket
    print_success "Podman configured for Docker compatibility"
fi

# Configure SELinux
print_info "Configuring SELinux for containers..."
setsebool -P container_manage_cgroup true
setsebool -P virt_use_fusefs true
setsebool -P virt_sandbox_use_all_caps true

# Configure firewall
print_info "Configuring firewall..."
systemctl enable --now firewalld

# Open required ports for Rancher
firewall-cmd --permanent --add-port=80/tcp
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=6443/tcp
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=10250/tcp
firewall-cmd --permanent --add-port=10254/tcp
firewall-cmd --permanent --add-masquerade
firewall-cmd --reload

print_success "Firewall configured with required ports"

# Configure kernel parameters
print_info "Configuring kernel parameters..."
cat > /etc/sysctl.d/99-rancher.conf << 'EOF'
# Rancher required kernel parameters
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
vm.overcommit_memory = 1
kernel.panic = 10
kernel.panic_on_oops = 1
EOF

# Load kernel modules
modprobe br_netfilter
echo 'br_netfilter' > /etc/modules-load.d/br_netfilter.conf

# Apply sysctl settings
sysctl --system

print_success "Kernel parameters configured"

# Configure cgroup v2 (CentOS 9 default)
print_info "Configuring cgroup v2..."
if [ ! -f /sys/fs/cgroup/cgroup.controllers ]; then
    print_warning "cgroup v2 not detected, this may cause issues"
else
    print_success "cgroup v2 detected and ready"
fi

# Create systemd override for better container support
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/override.conf << 'EOF'
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --host=fd:// --add-runtime docker-runc=/usr/libexec/docker/docker-runc-current --default-runtime=docker-runc --exec-opt native.cgroupdriver=systemd --userland-proxy-path=/usr/libexec/docker/docker-proxy-current --init-path=/usr/libexec/docker/docker-init-current --seccomp-profile=/etc/docker/seccomp.json --selinux-enabled --log-driver=journald --signature-verification=false --storage-driver overlay2
EOF

# Reload systemd and restart Docker
systemctl daemon-reload
if systemctl is-active --quiet docker; then
    systemctl restart docker
fi

# Create rancher user and group
print_info "Creating rancher user..."
if ! id "rancher" &>/dev/null; then
    useradd -r -s /bin/false rancher
    print_success "Rancher user created"
else
    print_info "Rancher user already exists"
fi

# Set up data directory with proper permissions
print_info "Setting up data directories..."
mkdir -p /opt/rancher/data
chown -R rancher:rancher /opt/rancher
chmod -R 755 /opt/rancher

# Create SELinux policy for Rancher
print_info "Creating SELinux policy for Rancher..."
cat > rancher.te << 'EOF'
module rancher 1.0;

require {
    type container_t;
    type container_file_t;
    type unconfined_t;
    class file { create write read open getattr setattr };
    class dir { create write read open getattr setattr search add_name remove_name };
}

allow container_t container_file_t:file { create write read open getattr setattr };
allow container_t container_file_t:dir { create write read open getattr setattr search add_name remove_name };
EOF

# Compile and install SELinux policy
if command -v checkmodule &> /dev/null; then
    checkmodule -M -m -o rancher.mod rancher.te
    semodule_package -o rancher.pp -m rancher.mod
    semodule -i rancher.pp
    rm -f rancher.te rancher.mod rancher.pp
    print_success "SELinux policy for Rancher installed"
fi

# Disable swap (recommended for Kubernetes)
print_info "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
print_success "Swap disabled"

# Configure ulimits
print_info "Configuring ulimits..."
cat > /etc/security/limits.d/99-rancher.conf << 'EOF'
# Rancher ulimits
* soft nofile 65536
* hard nofile 65536
* soft nproc 65536
* hard nproc 65536
EOF

print_success "Ulimits configured"

# Final system check
print_info "Performing final system check..."

# Check if all required services are running
services=("firewalld")
if systemctl is-active --quiet docker; then
    services+=("docker")
elif systemctl is-active --quiet podman; then
    services+=("podman")
fi

for service in "${services[@]}"; do
    if systemctl is-active --quiet "$service"; then
        print_success "$service is running"
    else
        print_error "$service is not running"
    fi
done

# Check if required ports are open
required_ports=(80 443 6443)
for port in "${required_ports[@]}"; do
    if firewall-cmd --query-port="$port/tcp" &>/dev/null; then
        print_success "Port $port is open"
    else
        print_warning "Port $port may not be open"
    fi
done

print_success "CentOS 9 system preparation completed!"
print_info "You can now run Rancher with: ./init.sh && docker-compose up -d"
print_warning "Please reboot the system to ensure all changes take effect"

cat << 'EOF'

==================== Next Steps ====================
1. Reboot the system: sudo reboot
2. After reboot, navigate to the rancher directory
3. Run: ./init.sh
4. Start Rancher: docker-compose up -d
5. Access Rancher at: https://your-server-ip
====================================================

EOF