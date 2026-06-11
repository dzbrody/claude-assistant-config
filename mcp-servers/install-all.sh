#!/bin/bash
# Copyright (c) 2026 Yom Shore Ventures LLC
# dba: CTO Rescues - https://ctorescues.com/
# Author: Daniel Brody (@dzbrody)
#
# Principal Place of Business:
# 8 The Green – Suite 12060
# Dover, Delaware 19901
# United States
#
# All rights reserved. Proprietary and confidential.

# install-all.sh — Install all MCP servers for Claude Code personal assistant
# Run from any directory. Requires the claude CLI to be installed and authenticated.
set -e

GDRIVE="$HOME/Library/CloudStorage"

echo "============================================"
echo "  Claude Personal Assistant — MCP Installer"
echo "============================================"
echo ""

# ---- Google Workspace (Email, Calendar, Tasks, Drive) ----
echo "[1/7] Adding google-workspace..."
claude mcp add --transport stdio google-workspace -- npx -y @alanxchen/google-workspace-mcp
echo "  ✓ google-workspace added"

# ---- WhatsApp Messaging ----
echo "[2/7] Adding whatsapp..."
claude mcp add --transport stdio whatsapp -- uv --directory /Users/dzbrody/whatsapp-mcp/whatsapp-mcp-server run main.py
echo "  ✓ whatsapp added"

# ---- Document Loader (read Office/PDF/Word files via markitdown) ----
echo "[3/7] Adding document-loader..."
claude mcp add --transport stdio document-loader -- uvx markitdown-mcp
echo "  ✓ document-loader added"

# ---- Filesystem ----
# Personal:
#   ~/Documents                         — personal files
#   ~/Downloads, ~/Desktop              — general staging
# Google Drive (XGC account):
#   My Drive                            — db@xgccorp.com personal drive
#   Shared drives/XGC                   — XGC company files
#   Shared drives/AXINAGRP              — AXINA group files
#   Shared drives/CCCL, Development,
#     dnloadfiles, XGC-WORKING_FILES    — other XGC shared drives
# Google Drive (personal accounts):
#   daniel@brody.ca                     — personal/4ward work
#   dzbrody99@gmail.com                 — personal Gmail drive
# OneDrive:
#   OneDrive-Personal                   — personal OneDrive
#   OneDrive                            — likely synced org/Teams files
echo "[4/7] Adding filesystem..."
claude mcp add --transport stdio filesystem -- npx -y @modelcontextprotocol/server-filesystem \
  "$HOME/Documents" \
  "$HOME/Downloads" \
  "$HOME/Desktop" \
  "$GDRIVE/GoogleDrive-db@xgccorp.com/My Drive" \
  "$GDRIVE/GoogleDrive-db@xgccorp.com/Shared drives/XGC" \
  "$GDRIVE/GoogleDrive-db@xgccorp.com/Shared drives/AXINAGRP" \
  "$GDRIVE/GoogleDrive-db@xgccorp.com/Shared drives/CCCL" \
  "$GDRIVE/GoogleDrive-db@xgccorp.com/Shared drives/Development" \
  "$GDRIVE/GoogleDrive-db@xgccorp.com/Shared drives/dnloadfiles" \
  "$GDRIVE/GoogleDrive-db@xgccorp.com/Shared drives/XGC-WORKING_FILES" \
  "$GDRIVE/GoogleDrive-daniel@brody.ca/My Drive" \
  "$GDRIVE/GoogleDrive-dzbrody99@gmail.com/My Drive" \
  "$GDRIVE/OneDrive-Personal" \
  "$HOME/OneDrive"
echo "  ✓ filesystem added"

# ---- Browser Automation ----
echo "[5/7] Adding playwright..."
claude mcp add --transport stdio playwright -- npx -y @playwright/mcp@latest
echo "  ✓ playwright added"

# ---- OpenProject + S3 Remote (EC2 — uses AWS Bedrock credits, not local) ----
# Get the API key from macOS Keychain (set once with security add-generic-password)
echo "[6/7] Adding openproject-remote..."
MCP_API_KEY=$(security find-generic-password -s "openproject-mcp-api-key" -w 2>/dev/null || true)
if [ -z "$MCP_API_KEY" ]; then
  echo "  ⚠️  MCP API key not found in Keychain."
  echo "  Add it once with:"
  echo "    security add-generic-password -a \"\$USER\" -s openproject-mcp-api-key -w <key>"
  echo "  Then re-run this script, or add manually:"
  echo "    claude mcp add --transport sse --scope user openproject-remote \\"
  echo "      \"https://projects.axinagroup.com/mcp/sse?key=<MCP_API_KEY>\""
else
  claude mcp add --transport sse --scope user openproject-remote \
    "https://projects.axinagroup.com/mcp/sse?key=${MCP_API_KEY}"
  echo "  ✓ openproject-remote added (EC2 remote, uses AWS Bedrock credits)"
fi

# ---- Office365 Local (control Word/Excel/PowerPoint desktop apps) ----
echo "[7/7] office365-local..."
echo "  NOTE: Requires cloning https://github.com/vAirpower/macos-office365-mcp-server first."
echo "  Once cloned, run:"
echo "    claude mcp add --transport stdio office365-local -- /path/to/server/start.sh"
echo "  Skipping auto-install for office365-local."

echo ""
echo "============================================"
echo "  Core MCP servers installed."
echo "  Run 'claude mcp list' to verify."
echo "============================================"
echo ""
echo "Not yet configured (manual setup required):"
echo "  office365-local   — clone repo above, then add manually"
echo "  notion            — requires Notion API key + MCP server"
echo "  github            — for XGC/AXINA project tracking"
