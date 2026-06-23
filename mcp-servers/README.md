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
| `openproject-remote` | SSE | EC2 FastMCP server (Python 3.12) | OpenProject + S3 + Whisper transcription (remote, works anywhere) |

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

## Remote MCP Server

The remote server runs on EC2 at `https://projects.ctorescues.com/mcp/` and works from **any device** — Mac, mobile, or any MCP client.

Source code: `openproject-mcp/` — this is the canonical server deployed to EC2.

**Tools available (49 total):**

| Module | Tools |
|--------|-------|
| `connection` | test_connection, check_permissions |
| `work_packages` | list, create, update, delete, list_types, list_statuses, list_priorities |
| `projects` | list, get, create, update, delete |
| `users` | list_users, get_user, list_roles, get_role, list_project_members, list_user_projects |
| `memberships` | list, get, create, update, delete |
| `hierarchy` | set_parent, remove_parent, list_children |
| `relations` | create, list, get, update, delete |
| `time_entries` | list, create, update, delete, list_activities |
| `versions` | list, create |
| `weekly_reports` | generate_weekly_report, get_report_data, generate_this_week_report, generate_last_week_report |
| `news` | list_news, create_news, get_news, update_news, delete_news |

**Connect via Claude CLI:**
```bash
claude mcp add --transport sse --scope user openproject-remote \
  "https://projects.ctorescues.com/mcp/sse?key=<MCP_API_KEY>"
```

**Connect via Claude Desktop** — Claude Desktop only supports stdio, so use `mcp-proxy` as a bridge. Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:
```json
"openproject-remote": {
  "command": "/Users/dzbrody/.local/bin/uvx",
  "args": ["mcp-proxy", "https://projects.ctorescues.com/mcp/sse?key=<MCP_API_KEY>"]
}
```

**Connect via Kiro** — add to `~/.kiro/settings/mcp.json`:
```json
"axina-mcp": {
  "command": "uvx",
  "args": ["mcp-proxy@latest", "https://projects.ctorescues.com/mcp/sse?key=<MCP_API_KEY>"],
  "env": {}
}
```

**Connect via Claude Mobile:**
- Settings → MCP Servers → Add Server
- URL: `https://projects.ctorescues.com/mcp/sse?key=<MCP_API_KEY>`

**API key:** stored in 1Password as **CTO Rescues MCP API Key** — ask Daniel if you don't have access.

Server source code: `openproject-mcp/` (full 49-tool implementation)
Infrastructure details: `../infrastructure/README.md`

### Deploy Updates to EC2

```bash
# 1. Tar and upload source
cd mcp-servers/openproject-mcp
tar czf /tmp/openproject-mcp-src.tar.gz src/ openproject-mcp-sse.py openproject-mcp-http.py openproject-mcp-fastmcp.py requirements.txt pyproject.toml
aws s3 cp /tmp/openproject-mcp-src.tar.gz s3://ctorescues-openproject-files/deploy/openproject-mcp-src.tar.gz

# 2. Pull and rebuild on EC2
aws ssm send-command --region us-east-1 --instance-ids YOUR_INSTANCE_ID \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["aws s3 cp s3://ctorescues-openproject-files/deploy/openproject-mcp-src.tar.gz /tmp/src.tar.gz && tar xzf /tmp/src.tar.gz -C /data/mcp-server/ && cd /opt/openproject && docker compose build mcp-server && docker compose up -d --no-deps mcp-server"]'
```

---

## Filesystem Paths

The `filesystem` MCP server has access to these directories. Adjust for your own username when setting up:

### Standard (all team members)
| Path | Purpose |
|------|---------|
| `~/Documents` | Local documents |
| `~/Downloads` | Staging/downloads |
| `~/Desktop` | Desktop files |

### Daniel's Extended Access (db@ctorescues.com drives)
The `install-all.sh` script includes the full Google Drive + OneDrive path list for `db@ctorescues.com`. Team members should edit `install-all.sh` to use their own drive paths.

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
