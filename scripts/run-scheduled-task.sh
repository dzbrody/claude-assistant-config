#!/bin/bash
# run-scheduled-task.sh — Run a scheduled-task prompt file via Claude CLI
# Usage: run-scheduled-task.sh <task-name>
# Example: run-scheduled-task.sh morning-briefing
#
# Extracts the ## Prompt section from the .md file, substitutes {date},
# and runs it non-interactively via `claude -p`.

set -euo pipefail

TASK_NAME="${1:-}"
if [ -z "$TASK_NAME" ]; then
  echo "Usage: $0 <task-name>"
  echo "Available tasks:"
  ls ~/.claude-assistant/scheduled-tasks/*.md | xargs -I{} basename {} .md
  exit 1
fi

TASK_FILE="$HOME/.claude-assistant/scheduled-tasks/${TASK_NAME}.md"
LOG_DIR="$HOME/logs/claude-assistant"
LOG_FILE="$LOG_DIR/${TASK_NAME}.log"
DATE=$(date '+%Y-%m-%d')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

export AWS_PROFILE=claude-assistant

echo "[$TIMESTAMP] Checking AWS credentials..."
if ! aws sts get-caller-identity --profile claude-assistant &>/dev/null; then
  echo "[$TIMESTAMP] ERROR: claude-assistant IAM credentials invalid or missing"
  echo "[$TIMESTAMP] Run: aws configure --profile claude-assistant"
  exit 1
fi
echo "[$TIMESTAMP] AWS credentials OK"

if [ ! -f "$TASK_FILE" ]; then
  echo "ERROR: Task file not found: $TASK_FILE"
  exit 1
fi

mkdir -p "$LOG_DIR"

echo "[$TIMESTAMP] Starting $TASK_NAME" >> "$LOG_FILE"

# Check WhatsApp bridge health (non-fatal — log warning and continue)
if ! curl -sf http://localhost:8080/api/health | grep -q '"connected":true' 2>/dev/null; then
  echo "[$TIMESTAMP] WARNING: WhatsApp bridge not healthy — WhatsApp steps may fail" >> "$LOG_FILE"
fi

# Extract everything after the first '## Prompt' line, then substitute {date}
PROMPT=$(awk '/^## Prompt/{found=1; next} found{print}' "$TASK_FILE" | sed "s/{date}/$DATE/g")

if [ -z "$PROMPT" ]; then
  echo "[$TIMESTAMP] ERROR: No ## Prompt section found in $TASK_FILE" >> "$LOG_FILE"
  exit 1
fi

# MCP config for the remote SSE server — passed explicitly so claude -p doesn't
# trigger an OAuth flow when re-connecting the SSE server in a fresh subprocess.
MCP_KEY=$(security find-generic-password -s "openproject-mcp-api-key" -w 2>/dev/null || \
  python3 -c "import json; d=json.load(open('$HOME/.claude.json')); print(d['mcpServers']['openproject-remote']['url'].split('key=')[1])" 2>/dev/null || true)

MCP_CONFIG_ARGS=()
if [ -n "$MCP_KEY" ]; then
  MCP_CONFIG_ARGS=(--mcp-config "{\"mcpServers\":{\"openproject-remote\":{\"type\":\"sse\",\"url\":\"https://projects.axinagroup.com/mcp/sse?key=${MCP_KEY}\"}}}")
fi

# Run Claude non-interactively with all permissions pre-approved (unattended cron)
echo "[$TIMESTAMP] Running claude -p ..." >> "$LOG_FILE"
TASK_OUTPUT=$(echo "$PROMPT" | claude -p --dangerously-skip-permissions "${MCP_CONFIG_ARGS[@]}" 2>&1)
echo "$TASK_OUTPUT" | tee -a "$LOG_FILE"

echo "[$TIMESTAMP] Completed $TASK_NAME" >> "$LOG_FILE"

# Send summary email to db@axinagroup.com
TASK_LABEL=$(echo "$TASK_NAME" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')
EMAIL_PROMPT="Use the google-workspace send_email tool to send an email with these exact details:
To: db@axinagroup.com
Subject: [Claude] ${TASK_LABEL} — ${DATE}
Body: Send the following output as a clean plain-text email, organized by section. Keep all section headers and bullet points. Remove any tool call artifacts or debug lines. Sign off as 'Claude Assistant':

${TASK_OUTPUT}"

echo "[$TIMESTAMP] Sending summary email..." >> "$LOG_FILE"
echo "$EMAIL_PROMPT" | claude -p --dangerously-skip-permissions "${MCP_CONFIG_ARGS[@]}" 2>&1 | tee -a "$LOG_FILE"
echo "[$TIMESTAMP] Email sent" >> "$LOG_FILE"
