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
    echo -e "$1"
}

log_warn() {
    echo -e "$1"
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

# Check if source directory exists
if [[ ! -d "/srv/data" ]]; then
    log_error "Source directory /srv/data does not exist!"
    exit 1
fi

# Check if backup directory exists, create if not
if [[ ! -d "/srv/backup" ]]; then
    log_warn "Backup directory /srv/backup does not exist, creating..."
    mkdir -p /srv/backup || {
        log_error "Failed to create backup directory /srv/backup"
        exit 1
    }
fi

# Create backup with error output visible
log_info "Backing up service data to [[${BACKUP_PATH}]]"
TAR_OUTPUT=$(tar -czf "${BACKUP_PATH}" -C /srv data 2>&1)
TAR_EXIT_CODE=$?

if [[ ${TAR_EXIT_CODE} -eq 0 ]]; then
    # Verify backup was created and has content
    if [[ ! -f "${BACKUP_PATH}" ]]; then
        log_error "Backup file was not created!"
        exit 1
    fi
    
    BACKUP_SIZE=$(du -h "${BACKUP_PATH}" | cut -f1)
    if [[ "${BACKUP_SIZE}" == "0" ]] || [[ -z "${BACKUP_SIZE}" ]]; then
        log_error "Backup file is empty or invalid!"
        rm -f "${BACKUP_PATH}"
        exit 1
    fi
    
    log_info "Backup created: ${BACKUP_NAME} (${BACKUP_SIZE})"
    
    # Keep only last 10 backups
    log_info "Cleaning old backups (keeping last 10)..."
    cd /srv/backup || {
        log_error "Failed to change to backup directory"
        exit 1
    }
    ls -t backup_*.tar.gz 2>/dev/null | tail -n +11 | xargs -r rm -f
    log_info "Backup complete!"
else
    log_error "Backup failed with exit code: ${TAR_EXIT_CODE}"
    if [[ -n "${TAR_OUTPUT}" ]]; then
        log_error "Error details: ${TAR_OUTPUT}"
    fi
    log_error "Common causes:"
    log_error "  - Insufficient disk space (check: df -h /srv/backup)"
    log_error "  - Permission denied (check: ls -ld /srv/backup /srv/data)"
    log_error "  - Source directory missing or empty"
    # Clean up partial backup if it exists
    [[ -f "${BACKUP_PATH}" ]] && rm -f "${BACKUP_PATH}"
    exit 1
fi
