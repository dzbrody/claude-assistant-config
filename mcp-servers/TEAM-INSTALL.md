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

The WhatsApp MCP server bridges Claude to your WhatsApp account. Requires WhatsApp on your phone.

```bash
# Clone the WhatsApp bridge
git clone https://github.com/lharries/whatsapp-mcp ~/whatsapp-mcp
cd ~/whatsapp-mcp/whatsapp-mcp-server
uv sync

# Start it and scan the QR code with WhatsApp on your phone
python main.py
```

Once the QR code is scanned and you see "Connected", press `Ctrl+C`. Claude will start the bridge automatically going forward.

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
— Re-run `python ~/whatsapp-mcp/whatsapp-mcp-server/main.py` and scan the QR code again.

**Google Workspace shows authentication error**
— Run the server directly once to complete OAuth: `npx -y @alanxchen/google-workspace-mcp`

---

## Getting Help

- Slack `#claude-ai` channel
- Check `infrastructure/README.md` for server-side issues
- Contact Daniel (db@xgccorp.com) for API key access
