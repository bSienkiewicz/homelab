#!/bin/bash
# Quick update script: git pull + apply all changes
# Run with: ./scripts/update.sh

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

log_info "Updating repository..."
echo ""

# Check if we're in a git repository
if [[ ! -d ".git" ]]; then
    log_error "Not a git repository!"
    exit 1
fi

# Check for uncommitted changes
if [[ -n $(git status --porcelain) ]]; then
    log_warn "You have uncommitted changes. Consider committing or stashing them first."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Update cancelled."
        exit 0
    fi
fi

# Pull latest changes
log_info "Pulling latest changes from git..."
if git pull; then
    log_info "Git pull successful"
else
    log_error "Git pull failed!"
    exit 1
fi

echo ""
log_info "Applying changes..."
echo ""

# Run apply script
if bash "$SCRIPT_DIR/apply.sh"; then
    log_info ""
    log_info "Update complete!"
    log_info ""
    log_info "To check status: docker compose ps"
else
    log_error "Apply failed!"
    exit 1
fi
