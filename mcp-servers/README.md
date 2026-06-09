# MCP Servers

MCP servers extend Claude with tools for email, calendar, messaging, files, browser automation, and project management.

## Current Servers

| Server | Transport | Package / Command | What It Does |
|--------|-----------|------------------|--------------|
| `google-workspace` | stdio | `@alanxchen/google-workspace-mcp` | Gmail, Calendar, Drive, Tasks |
| `whatsapp` | stdio | local Python + Go bridge | WhatsApp messages and media (bridge must be running) |
| `document-loader` | stdio | `uvx markitdown-mcp` | Read PDF/Office/Word files |
| `filesystem` | stdio | `@modelcontextprotocol/server-filesystem` | Controlled file access |
| `playwright` | stdio | `@playwright/mcp@latest` | Browser automation |
| `aws-s3-local` | stdio | `@iflow-mcp/samuraikun-aws-s3-mcp` | S3 file access (local/CLI) |
| `openproject-remote` | SSE | EC2 FastMCP server (Python 3.13) | OpenProject + S3 (remote, works anywhere) |

---

## WhatsApp Architecture

WhatsApp requires two components running on your Mac:

```
Claude (MCP client)
    │
    ▼
whatsapp-mcp-server (Python, stdio)   ← Claude talks to this
    │  HTTP on localhost:8080
    ▼
whatsapp-bridge (Go, persistent)      ← this holds the WhatsApp session
    │  WebSocket
    ▼
WhatsApp servers
```

**The Go bridge must be running** for WhatsApp tools to work. It is installed as a launchd service that starts at login and stays alive permanently. The QR code link is **one-time only** — the session is stored in `~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db`.

**v0.3.0+ requires Bearer token auth.** Token is auto-generated on first start at `store/.bridge-token`. The Python MCP server reads it automatically.

Check bridge status:
```bash
TOKEN=$(cat ~/whatsapp-mcp/whatsapp-bridge/store/.bridge-token)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/health
```

If the bridge is failing with `405 client outdated`, rebuild the binary:
```bash
launchctl unload ~/Library/LaunchAgents/com.dzbrody.whatsapp-bridge.plist
cd ~/whatsapp-mcp && git pull
cd whatsapp-bridge && go build -o whatsapp-bridge .
launchctl load ~/Library/LaunchAgents/com.dzbrody.whatsapp-bridge.plist
```

Full setup: see `TEAM-INSTALL.md` Step 5.

---

## Install All Local Servers

```bash
bash install-all.sh
```

This registers all local (stdio) servers with Claude CLI at user scope.

---

## Remote MCP Server (AXINA)

The remote server runs on EC2 at `https://projects.axinagroup.com/mcp/` and works from **any device** — Mac, mobile, or any MCP client.

**Tools available (10 total):**

| Tool | Description |
|------|-------------|
| `list_projects` | List all OpenProject projects |
| `get_project` | Get project details |
| `create_work_package` | Create a task / bug / feature in a project |
| `list_work_packages` | List work packages in a project (with optional status filter) |
| `update_work_package` | Update subject, description, status, or assignee (requires lockVersion) |
| `search_work_packages` | Search work packages by keyword across all or a specific project |
| `list_s3_buckets` | List accessible S3 buckets |
| `list_s3_objects` | List files in a bucket |
| `get_s3_object` | Read a text file from S3 (truncated at 10KB) |
| `search_s3_objects` | Search file names across S3 buckets |

**Connect via Claude CLI:**
```bash
claude mcp add --transport sse --scope user openproject-remote \
  "https://projects.axinagroup.com/mcp/sse?key=<MCP_API_KEY>"
```

**Connect via Claude Desktop** — Claude Desktop only supports stdio, so use `mcp-proxy` as a bridge. Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:
```json
"openproject-remote": {
  "command": "/Users/dzbrody/.local/bin/uvx",
  "args": ["mcp-proxy", "https://projects.axinagroup.com/mcp/sse?key=<MCP_API_KEY>"]
}
```

**Connect via Kiro** — add to `~/.kiro/settings/mcp.json`:
```json
"axina-mcp": {
  "command": "uvx",
  "args": ["mcp-proxy@latest", "https://projects.axinagroup.com/mcp/sse?key=<MCP_API_KEY>"],
  "env": {}
}
```

**Connect via Claude Mobile:**
- Settings → MCP Servers → Add Server
- URL: `https://projects.axinagroup.com/mcp/sse?key=<MCP_API_KEY>`

**API key:** stored in 1Password as **AXINA MCP API Key** — ask Daniel if you don't have access.

Server source code: `remote-mcp-server/server.py`
Infrastructure details: `../infrastructure/README.md`

---

## Filesystem Paths

The `filesystem` MCP server has access to these directories. Adjust for your own username when setting up:

### Standard (all team members)
| Path | Purpose |
|------|---------|
| `~/Documents` | Local documents |
| `~/Downloads` | Staging/downloads |
| `~/Desktop` | Desktop files |

### Daniel's Extended Access (db@xgccorp.com drives)
The `install-all.sh` script includes the full Google Drive + OneDrive path list for `db@xgccorp.com`. Team members should edit `install-all.sh` to use their own drive paths.

---

## Add / Remove Servers

```bash
# Add a stdio server (npm package)
claude mcp add --transport stdio --scope user <name> -- npx -y <package>

# Add a stdio server (Python via uv)
claude mcp add --transport stdio --scope user <name> -- uv --directory /path/to/project run main.py

# Add a remote SSE server
claude mcp add --transport sse --scope user <name> "https://your-server/sse"

# Remove a server
claude mcp remove <name>

# List all servers and check health
claude mcp list
```

---

## Planned / Not Yet Active

| Server | Notes |
|--------|-------|
| `github` | GitHub issues/PRs — needs GitHub PAT |
| `notion` | Notion pages — needs Notion API key |
