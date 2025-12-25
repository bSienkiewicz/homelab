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
check "env/common.env exists" test -f env/common.env
if [[ -f env/secrets.env ]]; then
    echo -e "${GREEN}✓${NC} env/secrets.env exists"
else
    warn "env/secrets.env does not exist (copy from env/secrets.env.example)"
fi

# Compose file checks
compose_count=0
for stack_dir in docker/*/; do
    if [[ -f "$stack_dir/docker-compose.yml" ]]; then
        ((compose_count++)) || true
    fi
done

if [[ $compose_count -gt 0 ]]; then
    echo -e "${GREEN}✓${NC} Found $compose_count compose stack(s)"
else
    warn "No compose stacks found in docker/"
fi

# Service health checks
if docker info >/dev/null 2>&1; then
    echo ""
    echo "Service status:"
    for stack_dir in docker/*/; do
        if [[ -f "$stack_dir/docker-compose.yml" ]]; then
            stack_name=$(basename "$stack_dir")
            cd "$stack_dir"
            if docker compose ps --format json 2>/dev/null | grep -q "running"; then
                running=$(docker compose ps --format json 2>/dev/null | jq -r 'select(.State == "running") | .Name' | wc -l)
                total=$(docker compose ps --format json 2>/dev/null | jq -r '.Name' | wc -l)
                echo "  $stack_name: $running/$total containers running"
            else
                echo "  $stack_name: no containers running"
            fi
            cd "$REPO_ROOT"
        fi
    done
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

