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

# run-scheduled-task.sh — Run a scheduled-task prompt file via Claude CLI
# Usage: run-scheduled-task.sh <task-name>
# Example: run-scheduled-task.sh morning-briefing
#
# Runs claude interactively so tool calls and progress stream live.

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
TASK_LABEL=$(echo "$TASK_NAME" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2); print}')

# Claude uses AWS Bedrock — export required env vars so they survive non-interactive cron runs
export CLAUDE_CODE_USE_BEDROCK=1
export AWS_PROFILE=xgc-main
export AWS_REGION=us-east-1
export AWS_DEFAULT_REGION=us-east-1
export ANTHROPIC_DEFAULT_SONNET_MODEL='us.anthropic.claude-sonnet-4-6[1m]'
export ANTHROPIC_DEFAULT_OPUS_MODEL='global.anthropic.claude-opus-4-6-v1[1m]'
export ANTHROPIC_DEFAULT_HAIKU_MODEL='us.anthropic.claude-haiku-4-5-20251001-v1:0'

# Resolve claude binary
CLAUDE_BIN=$(command -v claude 2>/dev/null || echo "$HOME/.local/bin/claude")

echo "[$TIMESTAMP] Checking AWS credentials..."
AWS_CRED_CACHE="$HOME/.aws/.cred-cache-xgc-main"
_cache_age=$(( $(date +%s) - $(stat -f%m "$AWS_CRED_CACHE" 2>/dev/null || echo 0) ))
if [ $_cache_age -gt 1800 ]; then
  if ! aws sts get-caller-identity --profile xgc-main &>/dev/null; then
    echo "[$TIMESTAMP] ERROR: xgc-main AWS SSO session expired"
    echo "[$TIMESTAMP] Run: aws sso login --profile xgc-main"
    exit 1
  fi
  touch "$AWS_CRED_CACHE"
fi
echo "[$TIMESTAMP] AWS credentials OK"

if [ ! -f "$TASK_FILE" ]; then
  echo "ERROR: Task file not found: $TASK_FILE"
  exit 1
fi

mkdir -p "$LOG_DIR"
echo "[$TIMESTAMP] Starting $TASK_NAME" >> "$LOG_FILE"

# Check WhatsApp bridge health (non-fatal) — v0.3.0+ requires Bearer token
WA_TOKEN_FILE="$HOME/whatsapp-mcp/whatsapp-bridge/store/.bridge-token"
WA_TOKEN=$(cat "$WA_TOKEN_FILE" 2>/dev/null || echo "")
if ! curl -sf -m 3 -H "Authorization: Bearer $WA_TOKEN" http://localhost:8080/api/health | grep -q '"connected":true' 2>/dev/null; then
  echo "[$TIMESTAMP] WARNING: WhatsApp bridge not healthy — WhatsApp steps may fail" >> "$LOG_FILE"
fi

# Extract ## Prompt section, substitute {date}
PROMPT=$(awk '/^## Prompt/{found=1; next} found{print}' "$TASK_FILE" | sed "s/{date}/$DATE/g")

# Inject private people/JID data if present
PEOPLE_FILE="$(dirname "$TASK_FILE")/.people.private.md"
if [ -f "$PEOPLE_FILE" ]; then
  PROMPT=$(printf '%s' "$PROMPT" | PEOPLE_FILE="$PEOPLE_FILE" python3 -c "
import sys, re, os
prompt = sys.stdin.read()
with open(os.environ['PEOPLE_FILE']) as f:
    people = f.read()
placeholder = re.compile(r'> Phone numbers, WhatsApp JIDs.*?Do not add them here\.\n?', re.DOTALL)
result = placeholder.sub(people + '\n', prompt, count=1)
sys.stdout.write(result)
")
fi

if [ -z "$PROMPT" ]; then
  echo "[$TIMESTAMP] ERROR: No ## Prompt section found in $TASK_FILE" >> "$LOG_FILE"
  exit 1
fi

# Append email instruction to prompt so a single claude run handles both
EMAIL_INSTRUCTION="

---

When you have completed all of the above, send a summary email using the google-workspace send_email tool:
To: db@axinagroup.com
Subject: [Claude] ${TASK_LABEL} — ${DATE}
Body: A clean plain-text version of your output above, organized by section. Keep all section headers and bullet points. Remove any tool call artifacts or debug lines. Sign off as 'Claude Assistant'."

PROMPT="${PROMPT}${EMAIL_INSTRUCTION}"

# Write prompt to temp file — claude reads it as the initial message
PROMPT_FILE=$(mktemp /tmp/claude-prompt-XXXXXX)
trap 'rm -f "$PROMPT_FILE"' EXIT
printf '%s' "$PROMPT" > "$PROMPT_FILE"

echo "[$TIMESTAMP] Launching claude (interactive, streaming) | $CLAUDE_BIN" | tee -a "$LOG_FILE"
echo ""

# Single invocation handles task work + email — no second claude spawn needed
"$CLAUDE_BIN" \
  --dangerously-skip-permissions \
  --print \
  < "$PROMPT_FILE" \
  2>&1 | tee -a "$LOG_FILE"

EXIT_CODE=${PIPESTATUS[0]}

if [ $EXIT_CODE -ne 0 ]; then
  echo "[$TIMESTAMP] ERROR: claude exited $EXIT_CODE" | tee -a "$LOG_FILE"
  exit 1
fi

echo "" && echo "[$TIMESTAMP] Completed $TASK_NAME" | tee -a "$LOG_FILE"
