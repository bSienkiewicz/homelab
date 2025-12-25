#!/bin/bash
# Backup script: creates tar archive of /srv/data with timestamp and git info
# Run with: ./scripts/backup.sh
# Typically triggered by GitHub webhook on push to main

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

# Get git info
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Create backup filename
BACKUP_NAME="backup_${GIT_BRANCH}_${GIT_COMMIT}_${TIMESTAMP}.tar.gz"
BACKUP_PATH="/srv/backup/${BACKUP_NAME}"

log_info "Creating backup..."
log_info "Branch: ${GIT_BRANCH}"
log_info "Commit: ${GIT_COMMIT}"
log_info "Timestamp: ${TIMESTAMP}"

# Create backup
if tar -czf "${BACKUP_PATH}" -C /srv data 2>/dev/null; then
    BACKUP_SIZE=$(du -h "${BACKUP_PATH}" | cut -f1)
    log_info "Backup created: ${BACKUP_NAME} (${BACKUP_SIZE})"
    
    # Keep only last 10 backups
    log_info "Cleaning old backups (keeping last 10)..."
    cd /srv/backup
    ls -t backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f
    log_info "Backup complete!"
else
    log_error "Backup failed!"
    exit 1
fi
