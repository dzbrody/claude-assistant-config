# Team Installation Guide

Step-by-step setup for a new Mac. Takes about 30 minutes end to end.

---

## What You'll Have When Done

- **🤖 Claude Assistant menu bar app** — click to run morning/evening/weekend/weekly briefings
- Claude CLI connected to OpenProject, Google Workspace, WhatsApp, S3, and your filesystem
- Claude Desktop with the same tools (optional)
- The CTO Rescues remote MCP server accessible from mobile and any IDE

---

## Before You Start

You need:
- macOS 13 or later
- An Anthropic account (claude.ai)
- Access to the CTO Rescues 1Password vault (for the MCP API key)
- An OpenProject account at https://projects.ctorescues.com (ask Daniel to create one)
- AWS SSO access on the `xgc-main` profile

---

## Step 1 — Install prerequisites

```bash
# Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Core tools
brew install node uv awscli python@3.12

# Claude CLI
npm install -g @anthropic/claude-code

# Python rumps library (menu bar app — must use 3.12, not 3.14)
/usr/local/bin/pip3.12 install rumps --break-system-packages

# Verify
claude --version
/usr/local/bin/python3.12 -c "import rumps; print('rumps OK')"
```

---

## Step 2 — Clone this repo

```bash
git clone <repo-url> ~/.claude-assistant
```

---

## Step 3 — Register local MCP servers

```bash
cd ~/.claude-assistant
bash mcp-servers/install-all.sh
```

> **Note:** `install-all.sh` includes filesystem paths for `db@ctorescues.com` Google Drive.
> If you use different Google accounts, edit the filesystem paths in the script first.

Verify:
```bash
claude mcp list
```

---

## Step 4 — Connect the CTO Rescues remote MCP server

1. Get the API key from 1Password: **CTO Rescues MCP API Key**
2. Run:

```bash
claude mcp add --transport sse --scope user openproject-remote \
  "https://projects.ctorescues.com/mcp/sse?key=<PASTE_KEY_HERE>"
```

3. Test:
```bash
claude "List my OpenProject projects"
```

---

## Step 5 — Set up WhatsApp

WhatsApp requires two components:
- **Go bridge** — connects to WhatsApp's servers, runs as a persistent background service
- **Python MCP server** — Claude talks to this, which talks to the bridge

### 5a — Clone and build

```bash
# Install Go if needed
brew install go

git clone https://github.com/lharries/whatsapp-mcp ~/whatsapp-mcp

# Build the Go bridge
cd ~/whatsapp-mcp/whatsapp-bridge
go build -o whatsapp-bridge .

# Install Python MCP server dependencies
cd ~/whatsapp-mcp/whatsapp-mcp-server
uv sync
```

### 5b — Link your WhatsApp account (one-time)

```bash
osascript -e 'tell application "Terminal"
  activate
  do script "/Users/'$USER'/whatsapp-mcp/whatsapp-bridge/whatsapp-bridge"
end tell'
```

On your phone: **WhatsApp → Settings → Linked Devices → Link a Device** → scan the QR code.

Confirm it worked:
```bash
curl http://localhost:8080/api/health
# {"connected":true,"status":"ok",...}
```

The session is saved to `~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db` — **you never need to scan a QR code again** on this machine.

### 5c — Install as a background service (auto-starts at login)

```bash
mkdir -p ~/logs/claude-assistant
cat > ~/Library/LaunchAgents/com.$USER.whatsapp-bridge.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.$USER.whatsapp-bridge</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/$USER/whatsapp-mcp/whatsapp-bridge/whatsapp-bridge</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/$USER/whatsapp-mcp/whatsapp-bridge</string>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><true/>
    <key>StandardOutPath</key>
    <string>/Users/$USER/logs/claude-assistant/whatsapp-bridge.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/$USER/logs/claude-assistant/whatsapp-bridge.log</string>
    <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.$USER.whatsapp-bridge.plist
launchctl list | grep whatsapp-bridge   # should show a PID
```

---

## Step 6 — Install the menu bar app

This is how you run the morning/evening/weekend/weekly briefings with one click.

```bash
chmod +x ~/.claude-assistant/desktop/build.sh
~/.claude-assistant/desktop/build.sh
# Answer y to install LaunchAgent (starts app at login)
```

Open `~/Applications/Claude Assistant.app` — look for 🤖 in your menu bar.

### Grant accessibility permission (required)

The app pastes prompts into Terminal using AppleScript keystrokes. macOS requires explicit permission:

1. **System Settings → Privacy & Security → Accessibility**
2. Click **+** → add **Terminal**
3. Enable the toggle

Without this, the terminal window opens but the prompt won't paste automatically.

### AWS session

Each briefing checks your AWS SSO session before starting. If expired, it opens a browser for login. Make sure AWS CLI is configured:

```bash
aws sso login --profile xgc-main
aws sts get-caller-identity --profile xgc-main   # confirm it works
```

---

## Step 7 — Configure MCP servers for CLI mode

The menu bar app runs `claude` non-interactively from `~/.claude-assistant`. MCP servers must be defined in `.claude/settings.local.json` (the CLI does not read Claude Desktop's config file).

The project already has this file pre-configured. If you're using a different username or Google account, edit it:

```bash
nano ~/.claude-assistant/.claude/settings.local.json
```

Key paths to update:
- `whatsapp` → `--directory /Users/<YOUR_USERNAME>/whatsapp-mcp/whatsapp-mcp-server`
- `filesystem` → update Google Drive and OneDrive paths to your own
- `openproject-remote` → update the API key URL

---

## Step 8 — Configure Claude Desktop (optional)

Download Claude Desktop from https://claude.ai/download.

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

> Replace `<YOUR_USERNAME>` and `<MCP_API_KEY>` as needed.

```json
{
  "mcpServers": {
    "google-workspace": {
      "command": "npx",
      "args": ["-y", "@alanxchen/google-workspace-mcp"]
    },
    "whatsapp": {
      "command": "uv",
      "args": [
        "--directory",
        "/Users/<YOUR_USERNAME>/whatsapp-mcp/whatsapp-mcp-server",
        "run",
        "main.py"
      ]
    },
    "document-loader": {
      "command": "uvx",
      "args": ["markitdown-mcp"]
    },
    "filesystem": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-filesystem",
        "/Users/<YOUR_USERNAME>/Documents",
        "/Users/<YOUR_USERNAME>/Downloads",
        "/Users/<YOUR_USERNAME>/Desktop"
      ]
    },
    "aws-s3-local": {
      "command": "npx",
      "args": ["-y", "@iflow-mcp/samuraikun-aws-s3-mcp"],
      "env": {
        "AWS_REGION": "us-east-1",
        "S3_BUCKETS": "xgccloud-openproject-files"
      }
    },
    "openproject-remote": {
      "command": "/Users/<YOUR_USERNAME>/.local/bin/uvx",
      "args": ["mcp-proxy", "https://projects.ctorescues.com/mcp/sse?key=<MCP_API_KEY>"]
    }
  }
}
```

Restart Claude Desktop after saving.

---

## Step 9 — Connect Kiro IDE (optional)

Edit `~/.kiro/settings/mcp.json` and add inside `mcpServers`:

```json
"ctorescues-mcp": {
  "command": "uvx",
  "args": ["mcp-proxy@latest", "https://projects.ctorescues.com/mcp/sse?key=<MCP_API_KEY>"],
  "env": {},
  "disabled": false
}
```

Reload: **Cmd+Shift+P → "Kiro: Reload MCP Servers"**

---

## Step 10 — Connect Claude Mobile (optional)

1. Settings → **MCP Servers** → **Add Server**
2. Name: `CTO Rescues`
3. URL: `https://projects.ctorescues.com/mcp/sse?key=<MCP_API_KEY>`

---

## Step 11 — Install OpenProject → WhatsApp Notifier

Posts every `axina-group-admin` OpenProject change to the TSPG WhatsApp group every 15 minutes.

**Requires:** WhatsApp bridge running (Step 5 above).

Before installing, set your own API key in the script:
```bash
nano ~/.claude-assistant/scripts/openproject-whatsapp-notifier.py
# Set OP_API_KEY to your OpenProject access token
# (OpenProject → My Account → Access Tokens → Generate)
```

Then install:
```bash
mkdir -p ~/logs/claude-assistant
cat > ~/Library/LaunchAgents/com.$USER.openproject-notifier.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>com.$USER.openproject-notifier</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>/Users/$USER/.claude-assistant/scripts/openproject-whatsapp-notifier.py</string>
    </array>
    <key>StartInterval</key><integer>900</integer>
    <key>RunAtLoad</key><false/>
    <key>StandardOutPath</key>
    <string>/Users/$USER/logs/claude-assistant/op-notifier.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/$USER/logs/claude-assistant/op-notifier.log</string>
    <key>LimitLoadToSessionType</key><string>Aqua</string>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.$USER.openproject-notifier.plist
launchctl list | grep openproject-notifier
```

---

## Step 12 — Final verification

```bash
bash ~/.claude-assistant/scripts/health-check.sh
```

Or manually:
```bash
claude mcp list
curl http://localhost:8080/api/health
launchctl list | grep -E "whatsapp-bridge|openproject-notifier|claude-assistant"
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| 🤖 not visible in menu bar | Menu bar may be full — hold Cmd and drag icons. Check `pgrep -fl app.py` and `~/logs/claude-assistant/menu-bar.log` |
| Terminal opens but nothing pastes | Accessibility not granted — System Settings → Privacy & Security → Accessibility → add Terminal |
| Blank output / claude does nothing | AWS session likely expired — run `aws sso login --profile xgc-main` |
| `No module named 'rumps'` | Install for Python 3.12: `/usr/local/bin/pip3.12 install rumps --break-system-packages` |
| WhatsApp `"connected":false` | Session expired — stop bridge, run manually to get new QR code, scan, reload service |
| `claude: command not found` in Terminal | Script sources `~/.zshrc` — make sure claude is at `~/.local/bin/claude` (`which claude`) |
| Google Workspace auth error | Run once manually to complete OAuth: `npx -y @alanxchen/google-workspace-mcp` |
| `openproject-remote` times out | Test directly: `curl "https://projects.ctorescues.com/mcp/sse?key=<KEY>" --max-time 3` |

**Getting help:** Contact Daniel (db@ctorescues.com) for API key access or OpenProject account creation.
