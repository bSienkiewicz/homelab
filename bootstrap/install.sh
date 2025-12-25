#!/bin/bash
# Idempotent OS bootstrap script for homelab
# This is the ONLY script that touches the OS
# Run with: sudo bash bootstrap/install.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[  INFO  ]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[  WARN  ]${NC} $1"
}

log_error() {
    echo -e "${RED}[  ERROR  ]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

log_info "Starting homelab bootstrap..."

# Update package list
log_info "Updating package list..."
apt-get update -qq

# Install base tools
log_info "Installing base tools..."
apt-get install -y \
    curl \
    wget \
    git \
    ufw \
    unattended-upgrades \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    jq \
    vim \
    htop \
    net-tools

# Install Docker if not already installed
if ! command -v docker &> /dev/null; then
    log_info "Installing Docker..."
    
    # Add Docker's official GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    apt-get update -qq
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
    log_info "Docker already installed, skipping..."
fi

# Install Docker Compose standalone (v2 plugin is already installed, but keeping standalone for compatibility)
if ! command -v docker-compose &> /dev/null; then
    log_info "Installing Docker Compose standalone..."
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
else
    log_info "Docker Compose already installed, skipping..."
fi

# Create directory structure
log_info "Creating directory structure..."
mkdir -p /srv/data
mkdir -p /srv/data/nginx/ssl
mkdir -p /srv/data/nginx/html
mkdir -p /srv/data/noip
mkdir -p /srv/data/media
mkdir -p /srv/data/jellyfin
mkdir -p /srv/media/movies
mkdir -p /srv/media/tv
mkdir -p /srv/media/music
mkdir -p /srv/media/downloads
mkdir -p /srv/smb

# Set permissions (adjust as needed)
chown -R $SUDO_USER:$SUDO_USER /srv/data 2>/dev/null || true
chown -R $SUDO_USER:$SUDO_USER /srv/media 2>/dev/null || true
chown -R $SUDO_USER:$SUDO_USER /srv/smb 2>/dev/null || true

# Configure firewall
log_info "Configuring firewall (UFW)..."
ufw --force enable || true
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
ufw allow 445/tcp comment 'SMB'
ufw allow 139/tcp comment 'NetBIOS'

# Create shared Docker network for proxy
log_info "Creating shared Docker network..."
if ! docker network inspect proxy >/dev/null 2>&1; then
    docker network create proxy
    log_info "Created 'proxy' network"
else
    log_info "Network 'proxy' already exists, skipping..."
fi

# Add user to docker group (if not already)
if ! groups $SUDO_USER | grep -q docker; then
    log_info "Adding $SUDO_USER to docker group..."
    usermod -aG docker $SUDO_USER
    log_warn "User $SUDO_USER added to docker group. Log out and back in for changes to take effect."
else
    log_info "User $SUDO_USER already in docker group, skipping..."
fi

# Enable Docker to start on boot
log_info "Enabling Docker service..."
systemctl enable docker
systemctl start docker

# Install and enable homelab systemd service
log_info "Installing homelab systemd service..."
REPO_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SERVICE_FILE="/etc/systemd/system/homelab.service"

# Create service file with correct paths
sed -e "s|REPLACE_USER|$SUDO_USER|g" \
    -e "s|REPLACE_REPO_PATH|$REPO_PATH|g" \
    "$REPO_PATH/bootstrap/homelab.service" > "$SERVICE_FILE"

systemctl daemon-reload
systemctl enable homelab.service
log_info "Homelab service enabled (will start on boot)"

log_info "Bootstrap complete!"
log_info ""
log_info "Next steps:"
log_info "1. Copy env/secrets.env.example to env/secrets.env and fill in your secrets"
log_info "2. Run: git pull"
log_info "3. Run: ./scripts/apply.sh"
log_info ""
log_info "Services will automatically start on boot via systemd."
log_info "Note: If you were added to the docker group, log out and back in first."
