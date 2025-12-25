#!/bin/bash
# Convergence script: applies repo state to machine
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
if [[ ! -f "secrets.env" ]]; then
    log_error "secrets.env not found!"
    log_error "Copy secrets.env.example to secrets.env and fill in your secrets"
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

# Export environment variables for ${VAR} substitution in compose file
log_info "Loading environment variables..."
set -a
source "$REPO_ROOT/common.env" 2>/dev/null || true
source "$REPO_ROOT/secrets.env" 2>/dev/null || true
set +a

# Apply the stack
log_info "Applying docker-compose.yml..."
docker compose up -d --remove-orphans

log_info ""
log_info "Convergence complete!"
log_info ""
log_info "To check status: docker compose ps"
