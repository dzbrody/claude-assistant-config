#!/bin/bash

TASK="$1"
PROJ="/Users/dzbrody/.claude-assistant"
CLAUDE="$HOME/.local/bin/claude"
PROMPT_FILE="$PROJ/desktop/.tmp_${TASK}.txt"
DATE=$(date +%Y-%m-%d)

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

# Validate prompt
PROMPT=$(cat "$PROMPT_FILE" 2>/dev/null || true)
if [ -z "$PROMPT" ]; then
    echo "❌ Error: prompt file empty or missing: $PROMPT_FILE"
    exit 1
fi

LOG="$HOME/logs/claude-assistant/${TASK}-$(date +%H%M%S).log"
mkdir -p "$HOME/logs/claude-assistant"
echo "📋 Log: $LOG"
echo ""

# Spinner runs until claude produces first output, then clears itself
spinner() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    while true; do
        printf "\r${frames[$i]} Connecting to MCP servers and starting..."
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.12
    done
}

spinner &
SPIN_PID=$!

# Run claude, capturing to log; as soon as first line arrives kill spinner and print cleanly
"$CLAUDE" --dangerously-skip-permissions -p "$PROMPT" 2>&1 | while IFS= read -r line; do
    # Kill spinner on first line of output
    if [ -n "$SPIN_PID" ]; then
        kill "$SPIN_PID" 2>/dev/null
        printf "\r%-60s\r" ""
        SPIN_PID=""
    fi
    echo "$line"
    echo "$line" >> "$LOG"
done
EXIT_CODE=${PIPESTATUS[0]}

# Ensure spinner is dead
kill $SPIN_PID 2>/dev/null
printf "\r%-60s\r" ""

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Done. Log saved to: $LOG"
else
    echo "❌ claude exited with code $EXIT_CODE — see log: $LOG"
fi
