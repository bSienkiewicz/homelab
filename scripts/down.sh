#!/bin/bash
# Stop all stacks
# Run with: ./scripts/down.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT"

# Stop all stacks
for stack_dir in docker/*/; do
    if [[ -f "$stack_dir/docker-compose.yml" ]]; then
        echo "Stopping $(basename "$stack_dir")..."
        cd "$stack_dir"
        docker compose down
        cd "$REPO_ROOT"
    fi
done

echo "All stacks stopped!"

