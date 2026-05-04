#!/bin/bash

TASK="$1"
PROJ="/Users/dzbrody/.claude-assistant"
CLAUDE="$HOME/.local/bin/claude"
PROMPT_FILE="$PROJ/desktop/.tmp_${TASK}.txt"
DATE=$(date +%Y-%m-%d)
LOG="$HOME/logs/claude-assistant/${TASK}-$(date +%H%M%S).log"
mkdir -p "$HOME/logs/claude-assistant"

case "$TASK" in
    morning) LABEL="☀️  Morning Briefing" ;;
    evening) LABEL="🌙  Evening Wrap-Up" ;;
    weekend) LABEL="📅  Weekend Briefing" ;;
    weekly)  LABEL="📊  Weekly Review" ;;
    *)       LABEL="$TASK" ;;
esac

source ~/.zshrc 2>/dev/null
export AWS_PROFILE=xgc-main
cd "$PROJ"

echo ""
echo "🤖 $LABEL — $DATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Log: $LOG"
echo ""

# AWS session check
echo "🔐 Checking AWS session..."
if ! aws sts get-caller-identity --profile xgc-main &>/dev/null; then
    echo "⚠️  Session expired — logging in (browser will open)..."
    aws sso login --profile xgc-main
fi
echo "✅ AWS OK"
echo ""

# Validate prompt
PROMPT=$(cat "$PROMPT_FILE" 2>/dev/null)
if [ -z "$PROMPT" ]; then
    echo "❌ Prompt file empty: $PROMPT_FILE"
    exit 1
fi

echo "⏳ Running claude (output below)..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# unbuffer gives claude a PTY so it streams output instead of buffering until done
unbuffer "$CLAUDE" --dangerously-skip-permissions -p "$PROMPT" 2>&1 | tee "$LOG"
EXIT_CODE=${PIPESTATUS[0]}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Done."
else
    echo "❌ claude exited $EXIT_CODE"
fi

# Save a copy of terminal scrollback to log
echo "[$DATE $(date +%H:%M:%S)] Exit: $EXIT_CODE" >> "$LOG"
