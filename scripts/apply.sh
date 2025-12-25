#!/bin/bash
# Convergence script: applies repo state to machine
# This script destroys drift by reapplying all compose stacks
# Run with: ./scripts/apply.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker or run bootstrap/install.sh"
    exit 1
fi

# Check if secrets.env exists
if [[ ! -f "env/secrets.env" ]]; then
    log_error "env/secrets.env not found!"
    log_error "Copy env/secrets.env.example to env/secrets.env and fill in your secrets"
    exit 1
fi

# Ensure shared network exists
log_info "Ensuring shared 'proxy' network exists..."
if ! docker network inspect proxy >/dev/null 2>&1; then
    log_info "Creating 'proxy' network..."
    docker network create proxy
else
    log_info "Network 'proxy' already exists"
fi

# Function to apply a compose stack
apply_stack() {
    local stack_dir="$1"
    local stack_name=$(basename "$stack_dir")
    
    if [[ ! -f "$stack_dir/docker-compose.yml" ]]; then
        log_warn "No docker-compose.yml found in $stack_dir, skipping..."
        return
    fi
    
    log_info "Applying stack: $stack_name"
    cd "$stack_dir"
    
    # Load environment files (handle spaces and special chars)
    set -a
    source "$REPO_ROOT/env/common.env" 2>/dev/null || true
    source "$REPO_ROOT/env/secrets.env" 2>/dev/null || true
    set +a
    
    # Apply the stack (this destroys drift)
    docker compose up -d --remove-orphans
    
    cd "$REPO_ROOT"
    log_info "Stack $stack_name applied"
}

# Apply stacks in dependency order
log_info "Starting convergence..."
log_info ""

# 1. Proxy first (other services depend on it)
if [[ -d "docker/nginx" ]]; then
    apply_stack "docker/nginx"
fi

# 2. No-IP (independent)
if [[ -d "docker/noip" ]]; then
    apply_stack "docker/noip"
fi

# 3. Media stack
if [[ -d "docker/media" ]]; then
    apply_stack "docker/media"
fi

# 4. Any other stacks (alphabetically)
for stack_dir in docker/*/; do
    stack_name=$(basename "$stack_dir")
    if [[ "$stack_name" != "nginx" && "$stack_name" != "noip" && "$stack_name" != "media" ]]; then
        apply_stack "$stack_dir"
    fi
done

log_info ""
log_info "Convergence complete!"
log_info ""
log_info "To check status: ./scripts/status.sh"
