#!/bin/bash
# Check status of Docker containers
# Run with: ./scripts/status.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}ERROR: Docker is not running${NC}"
    exit 1
fi

echo -e "${BLUE}=== Docker Container Status ===${NC}"
echo ""

# Show status from docker-compose
if [[ -f "docker-compose.yml" ]]; then
    docker compose ps
else
    echo -e "${YELLOW}No docker-compose.yml found${NC}"
fi

echo ""
