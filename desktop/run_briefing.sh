#!/bin/bash
# Wrapper called by the menu bar app — handles env setup, spinner, and claude execution.
TASK="$1"
PROJ="/Users/dzbrody/.claude-assistant"
CLAUDE="$HOME/.local/bin/claude"
PROMPT_FILE="$PROJ/desktop/.tmp_${TASK}.txt"
DATE=$(date +%Y-%m-%d)

declare -A LABELS
LABELS[morning]="☀️  Morning Briefing"
LABELS[evening]="🌙  Evening Wrap-Up"
LABELS[weekend]="📅  Weekend Briefing"
LABELS[weekly]="📊  Weekly Review"
LABEL="${LABELS[$TASK]:-$TASK}"

# Load shell env + AWS profile
source ~/.zshrc 2>/dev/null
export AWS_PROFILE=xgc-main
cd "$PROJ"

echo ""
echo "🤖 $LABEL — $DATE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Spinner in background
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

# Read prompt and pass via --print flag; use printf to avoid any further expansion
PROMPT=$(cat "$PROMPT_FILE")
if [ -z "$PROMPT" ]; then
    kill $SPIN_PID 2>/dev/null
    echo ""
    echo "❌ Error: prompt file empty or missing: $PROMPT_FILE"
    exit 1
fi
"$CLAUDE" --dangerously-skip-permissions --output-format stream-json --print "$PROMPT" 2>&1 | \
    python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
        if obj.get('type') == 'assistant':
            for block in obj.get('message', {}).get('content', []):
                if block.get('type') == 'text':
                    print(block['text'], end='', flush=True)
    except json.JSONDecodeError:
        print(line, flush=True)
print()
"
EXIT_CODE=${PIPESTATUS[0]}

# Stop spinner and clear line
kill $SPIN_PID 2>/dev/null
wait $SPIN_PID 2>/dev/null
printf "\r%-40s\r" "" >&2

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Done. You can close this window."
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "❌ claude exited with code $EXIT_CODE — check above for errors"
fi
