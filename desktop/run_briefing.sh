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

# Validate prompt
PROMPT=$(cat "$PROMPT_FILE" 2>/dev/null)
if [ -z "$PROMPT" ]; then
    echo "❌ Prompt file empty or missing: $PROMPT_FILE"
    exit 1
fi

echo "⏳ Starting claude..."
echo ""

# Run claude — simple, no pipes, no subshells
"$CLAUDE" --dangerously-skip-permissions -p "$PROMPT" | tee "$LOG"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Done. Log: $LOG"
