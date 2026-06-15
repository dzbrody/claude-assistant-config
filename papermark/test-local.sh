#!/bin/bash
# Local Papermark build + run test
# Run from the papermark SOURCE directory (github.com/papermark/papermark clone)
# Usage: bash /path/to/claude-assistant/papermark/test-local.sh [path-to-papermark-source]
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="${1:-$(pwd)}"

echo "=== Papermark Local Build Test ==="
echo "Source: $SOURCE_DIR"
echo "Config: $SCRIPT_DIR"

# Verify we're in a papermark source tree
if [ ! -f "$SOURCE_DIR/package.json" ]; then
  echo "ERROR: No package.json found in $SOURCE_DIR"
  echo "Usage: bash test-local.sh /path/to/papermark-source"
  exit 1
fi

# Copy our validated build files into the source tree
cp "$SCRIPT_DIR/Dockerfile"               "$SOURCE_DIR/Dockerfile"
cp "$SCRIPT_DIR/next.config.docker.mjs"   "$SOURCE_DIR/next.config.docker.mjs"
cp "$SCRIPT_DIR/docker-entrypoint.sh"     "$SOURCE_DIR/docker-entrypoint.sh"
cp "$SCRIPT_DIR/docker-compose.local.yml" "$SOURCE_DIR/docker-compose.local.yml"

# Copy env if not already present
if [ ! -f "$SOURCE_DIR/.env.local" ]; then
  cp "$SCRIPT_DIR/.env.local.example" "$SOURCE_DIR/.env.local"
  echo "Created .env.local from example — edit if needed"
fi

echo ""
echo "--- Starting local stack (Ctrl+C to stop) ---"
cd "$SOURCE_DIR"
docker compose -f docker-compose.local.yml down --remove-orphans 2>/dev/null || true
docker compose -f docker-compose.local.yml up --build

echo ""
echo "=== Build test complete ==="
echo "If http://localhost:3000 loaded: local build is VALID — safe to deploy to EC2"
