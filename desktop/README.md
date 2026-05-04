# Claude Assistant — Menu Bar App

A native macOS menu bar app that runs your briefing tasks via the `claude` CLI.

## What it looks like

```
🤖  ← click in menu bar
├── ☀️  Morning Briefing
├── 🌙  Evening Wrap-Up
├── 📅  Weekend Briefing
├── 📊  Weekly Review
├── ─────────────────
└── Quit
```

Clicking any option opens a Terminal window and runs the full briefing prompt via `claude`.

## Quick Start

**Run directly (no install needed):**
```bash
python3 ~/.claude-assistant/desktop/app.py
```

**Build as a .app + optional login item:**
```bash
chmod +x ~/.claude-assistant/desktop/build.sh
~/.claude-assistant/desktop/build.sh
```

Then open `~/Applications/Claude Assistant.app` — or double-click it in Finder.

## How it works

1. Reads the `## Prompt` section from the relevant `.md` file in `scheduled-tasks/`
2. Substitutes `{date}` with today's date
3. Calls `~/.local/bin/claude --dangerously-skip-permissions -p "<prompt>"`
4. Output streams live in the Terminal window — you can watch progress in real time

## Requirements

- `rumps` Python library (installed via `pip3 install rumps --break-system-packages`)
- `claude` CLI at `~/.local/bin/claude`
- All MCP servers running (whatsapp bridge, google-workspace, openproject-remote, filesystem)

## Updating prompts

Just edit the `.md` files in `../scheduled-tasks/` — the app always reads them fresh on each run.
