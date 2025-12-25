#!/bin/bash
# Sanity checks for homelab health
# Run with: ./bootstrap/sanity.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

errors=0
warnings=0

check() {
    if "$@"; then
        echo -e "${GREEN}✓${NC} $1"
        return 0
    else
        echo -e "${RED}✗${NC} $1"
        ((errors++)) || true
        return 1
    fi
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((warnings++)) || true
}

echo "Running homelab sanity checks..."
echo ""

# Docker checks
check "Docker is installed" command -v docker &> /dev/null
check "Docker Compose is installed" command -v docker-compose &> /dev/null || docker compose version &> /dev/null

if docker info >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Docker daemon is running"
    
    # Network check
    if docker network inspect proxy >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} 'proxy' network exists"
    else
        warn "'proxy' network does not exist (run bootstrap/install.sh)"
    fi
else
    warn "Docker daemon is not running"
fi

# Directory checks
check "Directory /srv/data exists" test -d /srv/data
check "Directory /srv/media exists" test -d /srv/media
check "Directory /srv/smb exists" test -d /srv/smb

# File checks
check "common.env exists" test -f common.env
check "docker-compose.yml exists" test -f docker-compose.yml
if [[ -f secrets.env ]]; then
    echo -e "${GREEN}✓${NC} secrets.env exists"
else
    warn "secrets.env does not exist (copy from secrets.env.example)"
fi

# Service health checks
if docker info >/dev/null 2>&1 && [[ -f docker-compose.yml ]]; then
    echo ""
    echo "Service status:"
    running=$(docker compose ps --format json 2>/dev/null | jq -r 'select(.State == "running") | .Name' | wc -l) || running=0
    total=$(docker compose ps --format json 2>/dev/null | jq -r '.Name' | wc -l) || total=0
    if [[ $total -gt 0 ]]; then
        echo "  $running/$total containers running"
    else
        echo "  no containers running"
    fi
fi

echo ""
if [[ $errors -eq 0 && $warnings -eq 0 ]]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
elif [[ $errors -eq 0 ]]; then
    echo -e "${YELLOW}Checks passed with $warnings warning(s)${NC}"
    exit 0
else
    echo -e "${RED}Checks failed with $errors error(s) and $warnings warning(s)${NC}"
    exit 1
fi
