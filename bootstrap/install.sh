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

REPO_PATH=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

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
    net-tools \
    restic

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

# Remove the old standalone docker-compose (v1) binary if present.
# Everything in this repo uses the `docker compose` (v2) plugin syntax now.
if [[ -f /usr/local/bin/docker-compose ]]; then
    log_info "Removing redundant docker-compose v1 standalone binary..."
    rm -f /usr/local/bin/docker-compose
fi

# Create top-level directories only
# Containers will create subdirectories automatically with proper permissions
log_info "Creating directory structure..."
mkdir -p /srv/data
mkdir -p /srv/media
mkdir -p /srv/smb
mkdir -p /srv/backup

# Set base permissions (containers will create subdirectories as needed)
chown -R $SUDO_USER:$SUDO_USER /srv/data 2>/dev/null || true
chown -R $SUDO_USER:$SUDO_USER /srv/media 2>/dev/null || true
chown -R $SUDO_USER:$SUDO_USER /srv/smb 2>/dev/null || true
chown -R $SUDO_USER:$SUDO_USER /srv/backup 2>/dev/null || true
chmod -R 775 /srv/smb 2>/dev/null || true
chmod -R 755 /srv/backup 2>/dev/null || true

# Enable persistent IP forwarding (required for Tailscale subnet routing)
log_info "Enabling persistent IP forwarding..."
cat > /etc/sysctl.d/99-homelab-tailscale.conf <<'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl --system > /dev/null

# Install Tailscale if not already installed
if ! command -v tailscale &> /dev/null; then
    log_info "Installing Tailscale..."
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg > /dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/$(lsb_release -cs).tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list > /dev/null
    apt-get update -qq
    apt-get install -y tailscale
else
    log_info "Tailscale already installed, skipping..."
fi

systemctl enable --now tailscaled

# Bring Tailscale up (interactive login on first run, idempotent on re-run)
TAILSCALE_READY=false
CURRENT_BACKEND_STATE=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // "NeedsLogin"')

if [[ "$CURRENT_BACKEND_STATE" == "Running" ]] && tailscale ip -4 &> /dev/null; then
    log_info "Tailscale already connected (IP: $(tailscale ip -4))"
    TAILSCALE_READY=true
else
    # Auto-detect the LAN CIDR to advertise as a subnet route, unless overridden
    if [[ -n "${TAILSCALE_ADVERTISE_ROUTES:-}" ]]; then
        ROUTES="$TAILSCALE_ADVERTISE_ROUTES"
        log_info "Using TAILSCALE_ADVERTISE_ROUTES override: $ROUTES"
    else
        DEFAULT_IFACE=$(ip route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if ($i=="dev") print $(i+1)}')
        ROUTES=$(ip route show dev "$DEFAULT_IFACE" scope link 2>/dev/null | awk '{print $1}' | head -n1)
        if [[ -z "$ROUTES" ]]; then
            log_warn "Could not auto-detect a LAN CIDR to advertise; skipping --advertise-routes"
        else
            log_info "Auto-detected LAN CIDR to advertise: $ROUTES"
        fi
    fi

    log_info "Starting Tailscale login (interactive) - follow the URL below if prompted..."
    if [[ -n "${ROUTES:-}" ]]; then
        tailscale up --advertise-routes="$ROUTES" --accept-dns=false || true
    else
        tailscale up --accept-dns=false || true
    fi

    CURRENT_BACKEND_STATE=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // "NeedsLogin"')
    if [[ "$CURRENT_BACKEND_STATE" == "Running" ]] && tailscale ip -4 &> /dev/null; then
        log_info "Tailscale connected (IP: $(tailscale ip -4))"
        TAILSCALE_READY=true
    else
        log_warn "Tailscale is not connected yet (state: $CURRENT_BACKEND_STATE)"
    fi
fi

# Configure firewall - ONLY after Tailscale is confirmed connected, to avoid
# locking out SSH. If Tailscale isn't ready, leave the firewall untouched.
if [[ "$TAILSCALE_READY" == true ]]; then
    log_info "Tailscale is up - hardening firewall to Tailscale-only access..."
    log_warn "Verify you can reach this host at $(tailscale ip -4) from another session BEFORE closing this one."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow in on tailscale0
    ufw --force enable
else
    log_warn "Skipping firewall hardening this run - Tailscale is not confirmed connected."
    log_warn "Complete 'sudo tailscale up' login, then re-run 'sudo bash bootstrap/install.sh'."
fi

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
SERVICE_FILE="/etc/systemd/system/homelab.service"

# Create service file with correct paths
sed -e "s|REPLACE_USER|$SUDO_USER|g" \
    -e "s|REPLACE_REPO_PATH|$REPO_PATH|g" \
    "$REPO_PATH/bootstrap/homelab.service" > "$SERVICE_FILE"

systemctl daemon-reload
systemctl enable homelab.service
log_info "Homelab service enabled (will start on boot)"

# Set up secrets.env and the restic backup directory
SECRETS_FILE="$REPO_PATH/secrets.env"
if [[ ! -f "$SECRETS_FILE" ]]; then
    log_info "Creating secrets.env from secrets.env.example..."
    cp "$REPO_PATH/secrets.env.example" "$SECRETS_FILE"
    chown "$SUDO_USER:$SUDO_USER" "$SECRETS_FILE" 2>/dev/null || true
fi

if grep -qE '^RESTIC_REPO=.+' "$SECRETS_FILE" 2>/dev/null; then
    log_info "RESTIC_REPO already set in secrets.env, skipping prompt ($(grep '^RESTIC_REPO=' "$SECRETS_FILE"))"
else
    read -rp "Backup destination directory for restic repo [/srv/backup/homelab]: " BACKUP_DIR
    BACKUP_DIR="${BACKUP_DIR:-/srv/backup/homelab}"
    mkdir -p "$BACKUP_DIR"
    chown -R "$SUDO_USER:$SUDO_USER" "$BACKUP_DIR" 2>/dev/null || true
    if grep -qE '^#?\s*RESTIC_REPO=' "$SECRETS_FILE"; then
        sed -i "s|^#\?\s*RESTIC_REPO=.*|RESTIC_REPO=$BACKUP_DIR|" "$SECRETS_FILE"
    else
        echo "RESTIC_REPO=$BACKUP_DIR" >> "$SECRETS_FILE"
    fi
    log_info "Set RESTIC_REPO=$BACKUP_DIR in secrets.env"
fi

log_info "Bootstrap complete!"
log_info ""
if [[ "$TAILSCALE_READY" == true ]]; then
    log_info "Tailscale is connected. If you advertised a subnet route, approve it in the"
    log_info "Tailscale admin console: https://login.tailscale.com/admin/machines"
else
    log_warn "Tailscale is NOT connected yet - firewall hardening was skipped."
    log_warn "Complete login via 'sudo tailscale up', then re-run this script."
fi
log_info ""
log_info "Next steps:"
log_info "1. Fill in SAMBA_PASSWORD and RESTIC_PASSWORD in secrets.env"
log_info "2. Run: ./scripts/apply.sh"
log_info ""
log_info "Services will automatically start on boot via systemd."
log_info "Note: If you were added to the docker group, log out and back in first."
