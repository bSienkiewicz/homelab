#!/bin/bash
# Check status of all Docker containers across all compose stacks
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

echo -e "${BLUE}=== Docker Container Status ===${NC}"
echo ""

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo -e "${RED}ERROR: Docker is not running${NC}"
    exit 1
fi

# Function to show status of a compose stack
show_stack_status() {
    local stack_dir="$1"
    local stack_name=$(basename "$stack_dir")
    
    if [[ ! -f "$stack_dir/docker-compose.yml" ]]; then
        return
    fi
    
    echo -e "${YELLOW}--- Stack: $stack_name ---${NC}"
    cd "$stack_dir"
    
    # Load environment files
    set -a
    source "$REPO_ROOT/env/common.env" 2>/dev/null || true
    source "$REPO_ROOT/env/secrets.env" 2>/dev/null || true
    set +a
    
    docker compose ps
    
    cd "$REPO_ROOT"
    echo ""
}

# Show status for all stacks
for stack_dir in docker/*/; do
    if [[ -d "$stack_dir" ]]; then
        show_stack_status "$stack_dir"
    fi
done

# Also show overall Docker status
echo -e "${BLUE}=== All Docker Containers (system-wide) ===${NC}"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""
