#!/bin/bash
# ============================================================
# post-bootstrap.sh — Run after first OpenProject login
# 
# Prerequisites:
# 1. DNS for projects.axinagroup.com has propagated
# 2. You've logged into OpenProject and created an admin account
# 3. You've generated an API key at: Admin → API → Generate
# ============================================================
set -e

# ---- Configuration ----
API_KEY="$1"  # Pass your OpenProject API key as first argument

if [ -z "$API_KEY" ]; then
  echo "Usage: ./post-bootstrap.sh <OPENPROJECT_API_KEY>"
  echo "Generate key at: https://projects.axinagroup.com/admin/api"
  exit 1
fi

DOMAIN="projects.axinagroup.com"

# ---- Add API key to .env ----
echo "OPENPROJECT_API_KEY=${API_KEY}" >> /opt/openproject/.env
chmod 600 /opt/openproject/.env

# ---- Start MCP Server ----
cd /opt/openproject
docker-compose up -d --build mcp-server

echo ""
echo "============================================"
echo "  MCP Server Started"
echo "============================================"
echo ""
echo "Test it:"
echo "  curl https://${DOMAIN}/mcp/health"
echo ""
echo "Connect Claude CLI:"
echo "  claude mcp add --transport sse --scope user openproject-remote \\"
echo "    \"https://${DOMAIN}/mcp/sse?key=<MCP_API_KEY>\""
echo ""