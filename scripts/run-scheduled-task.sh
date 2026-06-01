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

# Claude uses AWS Bedrock — export required env vars so they survive non-interactive cron runs
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_PROFILE=xgc-main
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
export ANTHROPIC_DEFAULT_SONNET_MODEL='us.anthropic.claude-sonnet-4-6[1m]'
export ANTHROPIC_DEFAULT_OPUS_MODEL='global.anthropic.claude-opus-4-6-v1[1m]'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='us.anthropic.claude-haiku-4-5-20251001-v1:0'

# Use the current claude binary (updated via pnpm)
CLAUDE_BIN="/Users/dzbrody/Library/pnpm/bin/claude"

echo "[$TIMESTAMP] Checking AWS credentials..."
if ! aws sts get-caller-identity --profile xgc-main &>/dev/null; then
  echo "[$TIMESTAMP] ERROR: xgc-main AWS SSO session expired"
  echo "[$TIMESTAMP] Run: aws sso login --profile xgc-main"
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

# Inject private people/JID data if present (gitignored, not in the task file itself)
PEOPLE_FILE="$(dirname "$TASK_FILE")/.people.private.md"
if [ -f "$PEOPLE_FILE" ]; then
  PROMPT=$(echo "$PROMPT" | sed "s|> Phone numbers, WhatsApp JIDs.*injected at runtime.*\`run-scheduled-task.sh\`\. Do not add them here\.|$(cat "$PEOPLE_FILE")|")
fi

if [ -z "$PROMPT" ]; then
  echo "[$TIMESTAMP] ERROR: No ## Prompt section found in $TASK_FILE" >> "$LOG_FILE"
  exit 1
fi

# Run Claude non-interactively with all permissions pre-approved (unattended cron).
# MCP servers are loaded from ~/.claude.json (global config) — no --mcp-config needed.
echo "[$TIMESTAMP] Running claude -p ..." >> "$LOG_FILE"
TASK_OUTPUT=$(echo "$PROMPT" | "$CLAUDE_BIN" -p --dangerously-skip-permissions 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ] || [ -z "$TASK_OUTPUT" ]; then
  echo "[$TIMESTAMP] ERROR: claude -p exited $EXIT_CODE with empty/no output" >> "$LOG_FILE"
  exit 1
fi
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
echo "$EMAIL_PROMPT" | "$CLAUDE_BIN" -p --dangerously-skip-permissions 2>&1 | tee -a "$LOG_FILE"
echo "[$TIMESTAMP] Email sent" >> "$LOG_FILE"
