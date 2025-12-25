#!/bin/bash
# Start all stacks
# Run with: ./scripts/up.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Source environment files
set -a
source "$REPO_ROOT/env/common.env" 2>/dev/null || true
source "$REPO_ROOT/env/secrets.env" 2>/dev/null || true
set +a

# Start all stacks
for stack_dir in docker/*/; do
    if [[ -f "$stack_dir/docker-compose.yml" ]]; then
        echo "Starting $(basename "$stack_dir")..."
        cd "$stack_dir"
        docker compose up -d
        cd "$REPO_ROOT"
    fi
done

echo "All stacks started!"

