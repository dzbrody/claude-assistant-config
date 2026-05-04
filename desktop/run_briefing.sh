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

# Validate prompt file
PROMPT=$(cat "$PROMPT_FILE" 2>/dev/null || true)
if [ -z "$PROMPT" ]; then
    echo "❌ Error: prompt file empty or missing: $PROMPT_FILE"
    exit 1
fi

# Spinner
spinner() {
    local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
    local i=0
    while true; do
        printf "\r${frames[$i]} Working..." >&2
        i=$(( (i + 1) % ${#frames[@]} ))
        sleep 0.1
    done
}
spinner &
SPIN_PID=$!

"$CLAUDE" --dangerously-skip-permissions -p "$PROMPT"
EXIT_CODE=$?

kill $SPIN_PID 2>/dev/null
wait $SPIN_PID 2>/dev/null
printf "\r%-40s\r" "" >&2

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ Done. You can close this window."
else
    echo "❌ claude exited with code $EXIT_CODE"
fi
