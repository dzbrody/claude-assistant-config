# Team Installation Guide

Step-by-step setup for a new Mac. Takes about 20 minutes.

---

## What You'll Have When Done

- Claude CLI connected to OpenProject, Google Workspace, WhatsApp, S3, and your filesystem
- Claude Desktop with the same tools + scheduled briefings
- Kiro IDE connected to AXINA MCP server (if you use Kiro)
- The AXINA remote MCP server accessible from mobile

---

## Before You Start

You need:
- macOS 13 or later
- An Anthropic account (claude.ai)
- Access to the AXINA team 1Password vault (for the MCP API key)
- An OpenProject account at https://projects.axinagroup.com (ask Daniel to create one)
- AWS SSO access on the `xgc-main` profile (for S3 tools — optional)

---

## Step 1 — Install prerequisites

```bash
# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Core tools
brew install node uv awscli

# Claude CLI
npm install -g @anthropic/claude-code

# Verify
claude --version
node --version
uv --version
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

> **Note:** `install-all.sh` includes filesystem paths for `db@xgccorp.com` Google Drive.
> If you use different Google accounts, edit the filesystem paths in the script first.

Verify:
```bash
claude mcp list
```

Expected output (some may show ✗ until first run — that's normal for playwright and document-loader):
```
google-workspace:    ✓ Connected
whatsapp:            ✗ (needs WhatsApp bridge — see Step 5)
document-loader:     ✓ Connected
filesystem:          ✓ Connected
playwright:          ✓ Connected
aws-s3-local:        ✓ Connected
```

---

## Step 4 — Connect the AXINA remote MCP server

1. Get the API key from 1Password: **AXINA MCP API Key**
2. Run:

```bash
claude mcp add --transport sse --scope user openproject-remote \
  "https://projects.axinagroup.com/mcp/sse?key=<PASTE_KEY_HERE>"
```

3. Test:
```bash
claude "List my OpenProject projects"
```

You should see your OpenProject projects listed.

---

## Step 5 — Set up WhatsApp (optional)

The WhatsApp integration has two parts:
- **Go bridge** (`whatsapp-bridge`) — connects to WhatsApp's servers, runs as a persistent background service
- **Python MCP server** (`whatsapp-mcp-server`) — Claude talks to this, which talks to the bridge

### 5a — Clone and build

```bash
git clone https://github.com/lharries/whatsapp-mcp ~/whatsapp-mcp

# Build the Go bridge (requires Go — install with: brew install go)
cd ~/whatsapp-mcp/whatsapp-bridge
go build -o whatsapp-bridge .

# Install Python MCP server dependencies
cd ~/whatsapp-mcp/whatsapp-mcp-server
uv sync
```

### 5b — First-time link (one-time only)

The Go bridge needs to be linked to your WhatsApp account once. It opens a new Terminal window with a QR code:

```bash
osascript -e 'tell application "Terminal"
  activate
  do script "/Users/'$USER'/whatsapp-mcp/whatsapp-bridge/whatsapp-bridge"
end tell'
```

On your phone: **WhatsApp → Settings → Linked Devices → Link a Device** → scan the QR code.

Once linked you'll see `"connected":true` from the health check:
```bash
curl http://localhost:8080/api/health
# {"connected":true,"status":"ok","timestamp":...}
```

The session is saved to `~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db` — **you never need to scan a QR code again** on this machine.

### 5c — Install as a background service (launchd)

This keeps the bridge running permanently, auto-starting at every login:

```bash
mkdir -p ~/Library/LaunchAgents
cat > ~/Library/LaunchAgents/com.$USER.whatsapp-bridge.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.$USER.whatsapp-bridge</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/$USER/whatsapp-mcp/whatsapp-bridge/whatsapp-bridge</string>
    </array>
    <key>WorkingDirectory</key>
    <string>/Users/$USER/whatsapp-mcp/whatsapp-bridge</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/Users/$USER/.claude-assistant/logs/whatsapp-bridge.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/$USER/.claude-assistant/logs/whatsapp-bridge.log</string>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
</dict>
</plist>
EOF

mkdir -p ~/.claude-assistant/logs
launchctl load ~/Library/LaunchAgents/com.$USER.whatsapp-bridge.plist
```

Verify it's running:
```bash
launchctl list | grep whatsapp-bridge    # shows PID if running
curl http://localhost:8080/api/health    # {"connected":true,...}
```

> **Note:** The bridge requires your Mac to be logged in. It will start automatically at login and stay running. The 8 AM scheduled briefing works as long as your Mac is awake — which it will be if you're at your desk.

### Troubleshooting WhatsApp

| Symptom | Fix |
|---------|-----|
| `"connected":false` on health check | Session expired — re-scan QR: `launchctl stop com.$USER.whatsapp-bridge && osascript -e 'tell app "Terminal" to do script "~/whatsapp-mcp/whatsapp-bridge/whatsapp-bridge"'` |
| Bridge not running after reboot | Run `launchctl load ~/Library/LaunchAgents/com.$USER.whatsapp-bridge.plist` |
| MCP list_chats returns empty | Bridge is running but not yet synced — wait 10 seconds and retry |
| QR code times out before scan | It refreshes every 20s and shows 6 codes before giving up — restart the bridge to get a fresh set |

---

## Step 6 — Configure Claude Desktop

Download Claude Desktop from https://claude.ai/download if you haven't already.

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

> Replace `<YOUR_USERNAME>` with your Mac username (`whoami` in terminal) and `<MCP_API_KEY>` with the key from 1Password.

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
      "command": "npx",
      "args": ["-y", "@anthropic/mcp-document-loader"]
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
      "type": "sse",
      "url": "https://projects.axinagroup.com/mcp/sse?key=<MCP_API_KEY>"
    }
  },
  "preferences": {
    "coworkScheduledTasksEnabled": true,
    "coworkWebSearchEnabled": true,
    "allowAllBrowserActions": true
  }
}
```

**Restart Claude Desktop** after saving.

---

## Step 7 — Configure Kiro IDE (optional)

If you use Kiro, edit `~/.kiro/settings/mcp.json` and add the `axina-mcp` entry inside the `mcpServers` object:

```json
"axina-mcp": {
  "command": "uvx",
  "args": [
    "mcp-proxy@latest",
    "https://projects.axinagroup.com/mcp/sse?key=<MCP_API_KEY>"
  ],
  "env": {},
  "disabled": false
}
```

Then reload: **Cmd+Shift+P → "Kiro: Reload MCP Servers"**

You should see `axina-mcp` appear with 8 tools in the MCP panel.

---

## Step 8 — Connect Claude Mobile (optional)

In the Claude iOS/Android app:

1. Settings → **MCP Servers** → **Add Server**
2. Name: `AXINA Group`
3. URL: `https://projects.axinagroup.com/mcp/sse?key=<MCP_API_KEY>`
4. Save

Then try: *"List my OpenProject projects"* in the mobile app.

---

## Step 9 — Load scheduled tasks (optional)

If you want the automated morning/evening briefings:

1. Open Claude Desktop → **Schedule** → **+ New task**
2. Copy the prompt from `scheduled-tasks/morning-briefing.md`
3. Set schedule: **Every weekday at 7:00 AM**
4. Click **Run once** first to approve MCP permissions
5. Repeat for `evening-wrap-up.md` (6 PM) and `weekly-review.md` (Sunday 10 AM)

Note: The briefing prompts reference specific email addresses and WhatsApp numbers. Edit them if needed before loading.

---

## Step 10 — Final verification

```bash
bash ~/.claude-assistant/scripts/health-check.sh
```

Or manually:
```bash
# Check all MCP servers
claude mcp list

# Test remote MCP
claude "What OpenProject projects do we have?"

# Test filesystem
claude "List files in my Documents folder"
```

---

## Troubleshooting

**`claude: command not found`**
— Run `npm install -g @anthropic/claude-code` and make sure `/usr/local/bin` is in your `$PATH`.

**MCP server shows ✗ Failed to connect**
— This is sometimes normal on the first health check. Run `claude mcp list` again after 10 seconds. If it persists, check the package exists: `npx -y <package-name> --version`.

**`openproject-remote` times out**
— The SSE connection health check can time out even when the server is working. Test it directly: `curl "https://projects.axinagroup.com/mcp/sse?key=<KEY>" --max-time 3`

**WhatsApp shows disconnected**
— Check the bridge is running: `curl http://localhost:8080/api/health`. If `"connected":false`, the session may have expired. Stop the launchd service, start the bridge manually in a Terminal window to get a fresh QR code, scan it, then reload the service: `launchctl load ~/Library/LaunchAgents/com.$USER.whatsapp-bridge.plist`. You only need to do this if WhatsApp logs out the linked device (uncommon).

**Google Workspace shows authentication error**
— Run the server directly once to complete OAuth: `npx -y @alanxchen/google-workspace-mcp`

---

## Getting Help

- Slack `#claude-ai` channel
- Check `infrastructure/README.md` for server-side issues
- Contact Daniel (db@xgccorp.com) for API key access
