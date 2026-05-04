#!/bin/bash
# health-check.sh — Verify MCP servers, key directories, and scheduled task files
set -e

echo "=== Claude Assistant Health Check ==="
echo ""

# ---- MCP Servers ----
echo "MCP Servers:"
if command -v claude &>/dev/null; then
  claude mcp list 2>/dev/null
else
  echo "  ⚠️  claude CLI not found — run 'claude mcp list' manually after installing"
fi
echo ""

# ---- Daily Briefs Directory ----
echo "Daily Briefs Directory:"
BRIEFS_DIR="$HOME/Documents/daily_briefs"
if [ -d "$BRIEFS_DIR" ]; then
  COUNT=$(ls "$BRIEFS_DIR" 2>/dev/null | wc -l | tr -d ' ')
  echo "  ✓ $BRIEFS_DIR exists ($COUNT files)"
  ls -lt "$BRIEFS_DIR" 2>/dev/null | head -5
else
  echo "  ⚠️  $BRIEFS_DIR missing — creating it now"
  mkdir -p "$BRIEFS_DIR"
  echo "  ✓ Created $BRIEFS_DIR"
fi
echo ""

# ---- Config Repo ----
echo "Config Repo:"
REPO="$HOME/.claude-assistant"
if [ -d "$REPO/.git" ]; then
  echo "  ✓ Repo exists at $REPO"
  cd "$REPO" && git status --short 2>/dev/null
  LAST_COMMIT=$(git log -1 --format="%h %s" 2>/dev/null)
  echo "  Last commit: $LAST_COMMIT"
else
  echo "  ⚠️  Config repo not found at $REPO"
fi
echo ""

# ---- Scheduled Task Files ----
echo "Scheduled Task Files:"
TASKS=(
  "scheduled-tasks/morning-briefing.md"
  "scheduled-tasks/evening-wrap-up.md"
  "scheduled-tasks/weekend-briefing.md"
  "scheduled-tasks/weekly-review.md"
)
for f in "${TASKS[@]}"; do
  if [ -f "$REPO/$f" ]; then
    echo "  ✓ $f"
  else
    echo "  ✗ $f — MISSING"
  fi
done
echo ""

# ---- Install Script ----
echo "Install Script:"
if [ -x "$REPO/mcp-servers/install-all.sh" ]; then
  echo "  ✓ mcp-servers/install-all.sh (executable)"
else
  echo "  ⚠️  mcp-servers/install-all.sh not found or not executable"
fi
echo ""

# ---- Cloud Storage Mounts ----
echo "Cloud Storage Mounts:"
GDRIVE="$HOME/Library/CloudStorage"
MOUNTS=(
  "GoogleDrive-db@xgccorp.com/My Drive"
  "GoogleDrive-db@xgccorp.com/Shared drives/XGC"
  "GoogleDrive-db@xgccorp.com/Shared drives/AXINAGRP"
  "GoogleDrive-db@xgccorp.com/Shared drives/CCCL"
  "GoogleDrive-db@xgccorp.com/Shared drives/Development"
  "GoogleDrive-db@xgccorp.com/Shared drives/XGC-WORKING_FILES"
  "GoogleDrive-daniel@brody.ca/My Drive"
  "GoogleDrive-dzbrody99@gmail.com/My Drive"
  "OneDrive-Personal"
)
for m in "${MOUNTS[@]}"; do
  if [ -d "$GDRIVE/$m" ]; then
    echo "  ✓ $m"
  else
    echo "  ✗ $m — NOT MOUNTED (open Google Drive / OneDrive app)"
  fi
done
# OneDrive (org) lives at ~/OneDrive, not in CloudStorage
if [ -d "$HOME/OneDrive" ]; then
  echo "  ✓ ~/OneDrive (org/Teams)"
else
  echo "  ✗ ~/OneDrive — NOT MOUNTED"
fi
echo ""

# ---- Logs Directory ----
echo "Logs Directory:"
LOG_DIR="$HOME/logs/claude-assistant"
if [ -d "$LOG_DIR" ]; then
  COUNT=$(ls "$LOG_DIR" 2>/dev/null | wc -l | tr -d ' ')
  echo "  ✓ $LOG_DIR exists ($COUNT files)"
  ls -lt "$LOG_DIR" 2>/dev/null | head -5
else
  echo "  ⚠️  $LOG_DIR missing — will be created on first task run"
fi
echo ""

echo "=== Health Check Complete ==="
