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
    local desc="$1"
    shift
    if "$@"; then
        echo -e "${GREEN}✓${NC} $desc"
        return 0
    else
        echo -e "${RED}✗${NC} $desc"
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
check "Docker Compose plugin is installed" bash -c "docker compose version &> /dev/null"

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

# Tailscale checks
if command -v tailscale &> /dev/null; then
    echo -e "${GREEN}✓${NC} Tailscale is installed"

    TS_STATE=$(tailscale status --json 2>/dev/null | jq -r '.BackendState // "Unknown"')
    if [[ "$TS_STATE" == "Running" ]] && tailscale ip -4 &> /dev/null; then
        echo -e "${GREEN}✓${NC} Tailscale is connected (IP: $(tailscale ip -4))"

        # Best-effort: the exact JSON field for advertised routes can vary by
        # tailscale version, so this is informational only, not a hard pass/fail.
        TS_ROUTES=$(tailscale status --json 2>/dev/null | jq -r '(.Self.PrimaryRoutes // .Self.AllowedIPs // []) | join(",")' 2>/dev/null || echo "")
        if [[ -n "$TS_ROUTES" ]]; then
            echo -e "${GREEN}✓${NC} Tailscale advertised/allowed routes: $TS_ROUTES"
        else
            warn "No advertised routes detected for this node (check 'tailscale status' and the admin console manually)"
        fi
        warn "Route advertisement still requires manual approval in the Tailscale admin console: https://login.tailscale.com/admin/machines"
    else
        warn "Tailscale is installed but not connected (state: $TS_STATE) - run 'sudo tailscale up'"
    fi
else
    warn "Tailscale is not installed (run bootstrap/install.sh)"
fi

# Firewall check
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null || echo "inactive")
    if echo "$UFW_STATUS" | grep -q "^Status: active"; then
        if echo "$UFW_STATUS" | grep -q "tailscale0"; then
            echo -e "${GREEN}✓${NC} ufw is active and trusts the tailscale0 interface"
        else
            warn "ufw is active but has no tailscale0 rule - firewall may not be hardened yet (run bootstrap/install.sh)"
        fi
    else
        warn "ufw is not active"
    fi
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
    warn "secrets.env does not exist (run bootstrap/install.sh to create it)"
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
