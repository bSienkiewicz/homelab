#!/bin/bash
# Backup script: restic snapshot of /srv/data, with container pause/unpause
# Run with: ./scripts/backup.sh

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

DATA_PATH="/srv/data"

# Load config
set -a
source "$REPO_ROOT/common.env" 2>/dev/null || true
source "$REPO_ROOT/secrets.env" 2>/dev/null || true
set +a

if [[ -z "${RESTIC_REPO:-}" || -z "${RESTIC_PASSWORD:-}" ]]; then
    log_error "RESTIC_REPO and/or RESTIC_PASSWORD are not set."
    log_error "Set them in secrets.env (run bootstrap/install.sh, or edit secrets.env manually)."
    exit 1
fi
export RESTIC_PASSWORD

if ! command -v restic &> /dev/null; then
    log_error "restic is not installed. Run bootstrap/install.sh."
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running."
    exit 1
fi

if [[ ! -d "$DATA_PATH" ]]; then
    log_error "Source directory $DATA_PATH does not exist!"
    exit 1
fi

log_info "Starting homelab backup..."

# Initialize the restic repo on first use
if ! restic -r "$RESTIC_REPO" snapshots &> /dev/null; then
    log_warn "Restic repo not found at $RESTIC_REPO, initializing..."
    restic -r "$RESTIC_REPO" init
fi

# Capture IDs of containers currently in 'running' state
RUNNING_CONTAINERS=$(docker compose ps --status running -q)

# Ensure paused containers always get unpaused, even if backup fails
trap 'if [[ -n "${RUNNING_CONTAINERS:-}" ]]; then docker unpause $RUNNING_CONTAINERS 2>/dev/null || true; fi' EXIT

if [[ -n "$RUNNING_CONTAINERS" ]]; then
    log_info "Pausing running containers..."
    docker pause $RUNNING_CONTAINERS
else
    log_info "No running containers found to pause."
fi

log_info "Running restic backup of $DATA_PATH..."
restic -r "$RESTIC_REPO" backup "$DATA_PATH" \
    --tag homelab \
    --exclude="*/cache/*" \
    --exclude="*/tmp/*"

if [[ -n "$RUNNING_CONTAINERS" ]]; then
    log_info "Unpausing containers..."
    docker unpause $RUNNING_CONTAINERS
fi

log_info "Enforcing retention policy..."
restic -r "$RESTIC_REPO" forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 12 \
    --prune

log_info "Backup completed successfully!"
