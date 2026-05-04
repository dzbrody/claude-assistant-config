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

# Ensure AWS SSO session is valid — refresh if expired
echo "🔐 Checking AWS session (profile: xgc-main)..."
if ! aws sts get-caller-identity --profile xgc-main &>/dev/null; then
    echo "⚠️  Session expired — logging in (browser will open)..."
    aws sso login --profile xgc-main
    if ! aws sts get-caller-identity --profile xgc-main &>/dev/null; then
        echo "❌ AWS login failed — cannot continue"
        exit 1
    fi
fi
echo "✅ AWS session active"
echo ""

# Validate prompt
PROMPT=$(cat "$PROMPT_FILE" 2>/dev/null)
if [ -z "$PROMPT" ]; then
    echo "❌ Prompt file empty or missing: $PROMPT_FILE"
    exit 1
fi

echo "⏳ Starting claude..."
echo ""

# script -q gives claude a real PTY so it streams output instead of buffering
script -q "$LOG" "$CLAUDE" --dangerously-skip-permissions -p "$PROMPT"
EXIT_CODE=$?

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Done. Log: $LOG"
