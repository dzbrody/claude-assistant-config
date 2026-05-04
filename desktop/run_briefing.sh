#!/bin/bash
# Wrapper called by the menu bar app — handles env setup, spinner, and claude execution.
TASK="$1"
PROJ="/Users/dzbrody/.claude-assistant"
CLAUDE="$HOME/.local/bin/claude"
PROMPT_FILE="$PROJ/desktop/.tmp_${TASK}.txt"
DATE=$(date +%Y-%m-%d)

LABELS=(
  [morning]="☀️  Morning Briefing"
  [evening]="🌙  Evening Wrap-Up"
  [weekend]="📅  Weekend Briefing"
  [weekly]="📊  Weekly Review"
)
LABEL="${LABELS[$TASK]:-$TASK}"

# Load shell env + AWS profile
source ~/.zshrc 2>/dev/null
export AWS_PROFILE=xgc-main
cd "$PROJ"

echo ""
echo "🤖 $LABEL — $DATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Spinner on stderr so it doesn't mix with claude's stdout
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

# Run claude — pipe prompt via stdin to avoid shell expansion issues with long prompts
"$CLAUDE" --dangerously-skip-permissions -p "$(cat "$PROMPT_FILE")"
EXIT_CODE=$?

# Stop spinner and clear the line
kill $SPIN_PID 2>/dev/null
wait $SPIN_PID 2>/dev/null
printf "\r%-30s\r" "" >&2

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Done. You can close this window."
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ claude exited with code $EXIT_CODE"
fi
