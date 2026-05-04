# Claude Assistant — Menu Bar App

A native macOS menu bar app that runs your daily briefings with one click. Sits in the menu bar permanently, uses zero RAM when idle.

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

Clicking any option opens a Terminal window, launches `claude` interactively with the full prompt, and streams output live as it works through each step (~5–12 minutes depending on the task).

---

## How it works

1. Copies the `## Prompt` section from the relevant `.md` file in `../scheduled-tasks/` to the clipboard
2. Opens a new Terminal window and launches `claude --dangerously-skip-permissions`
3. Waits 8 seconds for claude to fully load (CLAUDE.md + MCP servers)
4. Pastes the prompt via Cmd+V and presses Enter
5. Claude runs interactively with a real TTY — full output streams to the terminal window

---

## Installation

### Prerequisites

```bash
# Python 3.12 (required — rumps has a known incompatibility with Python 3.14)
brew install python@3.12

# Install rumps (menu bar framework)
/usr/local/bin/pip3.12 install rumps --break-system-packages

# Verify
/usr/local/bin/python3.12 -c "import rumps; print('OK')"
```

### Build and launch the .app

```bash
chmod +x ~/.claude-assistant/desktop/build.sh
~/.claude-assistant/desktop/build.sh
```

- Answer **y** when asked about the LaunchAgent to start the app automatically at login
- Answer **n** to skip the login agent and launch manually

Then open `~/Applications/Claude Assistant.app` to start it.

### Grant accessibility permission (required for keystroke paste)

The app uses AppleScript to paste the prompt into Terminal. macOS requires explicit permission:

1. Open **System Settings → Privacy & Security → Accessibility**
2. Click **+** and add **Terminal**
3. Make sure the toggle is enabled

> Without this, the Terminal window will open and claude will launch, but the prompt won't be pasted automatically.

---

## Start at login

```bash
# Enable (installs LaunchAgent)
~/.claude-assistant/desktop/build.sh   # answer y when prompted

# Disable
launchctl unload ~/Library/LaunchAgents/com.dzbrody.claude-assistant.plist

# Re-enable
launchctl load ~/Library/LaunchAgents/com.dzbrody.claude-assistant.plist
```

---

## AWS session

Each briefing checks that your AWS SSO session is valid before launching claude. If the session is expired, it will run `aws sso login --profile xgc-main` which opens a browser tab for authentication.

Make sure your AWS CLI is configured:
```bash
aws sso login --profile xgc-main
```

---

## MCP servers

The app runs `claude` from `/Users/dzbrody/.claude-assistant` where `.claude/settings.local.json` defines all MCP servers for non-interactive mode. These include:

- `google-workspace` — Gmail, Calendar, Tasks
- `whatsapp` — TSPG group messages, media download, send
- `filesystem` — Google Drive, Documents, OneDrive
- `openproject-remote` — Create and list work packages
- `document-loader` — Read PDF/Office files

The WhatsApp bridge must be running for WhatsApp tools to work:
```bash
curl http://localhost:8080/api/health
# {"connected":true,...}
```

---

## Run without the app (command line)

```bash
bash ~/.claude-assistant/desktop/run_briefing.sh morning
bash ~/.claude-assistant/desktop/run_briefing.sh evening
bash ~/.claude-assistant/desktop/run_briefing.sh weekend
bash ~/.claude-assistant/desktop/run_briefing.sh weekly
```

---

## Files

| File | Purpose |
|------|---------|
| `app.py` | Menu bar app (Python 3.12 + rumps) |
| `build.sh` | Packages as `~/Applications/Claude Assistant.app`, optionally installs LaunchAgent |
| `run_briefing.sh` | Shell wrapper — checks AWS session, then runs claude |

---

## Logs

```bash
# Menu bar app log (errors, crashes)
tail -f ~/logs/claude-assistant/menu-bar.log
```

Briefing output appears live in the Terminal window that opens when you click a menu item. There is no separate log for individual runs — the terminal window IS the log.

---

## Updating prompts

Edit the `.md` files in `../scheduled-tasks/` — the app reads them fresh on every click. No restart needed.
