# Claude Personal Assistant — AXINA / XGC / 4ward.earth

AI coworker setup for Claude CLI, Claude Desktop, and Kiro IDE across three organizations.

**What this gives you:**
- Claude connected to Gmail, Google Calendar, WhatsApp, Google Drive, OneDrive, and S3
- Claude connected to OpenProject at https://projects.axinagroup.com from any device
- Automated morning briefings, evening wrap-ups, and weekly reviews
- Kiro IDE with AWS tools and AXINA MCP server

---

## Repository Structure

```
.claude-assistant/
├── README.md                        ← This file — start here
├── mcp-servers/
│   ├── README.md                    ← MCP server reference
│   ├── install-all.sh               ← Register all local servers with Claude CLI
│   └── remote-mcp-server/           ← AXINA remote MCP server (runs on EC2)
│       ├── server.py
│       └── Dockerfile
├── scheduled-tasks/
│   ├── README.md                    ← How to load into Claude Desktop
│   ├── morning-briefing.md          ← Weekday 7 AM brief
│   ├── evening-wrap-up.md           ← Weekday 6 PM wrap-up
│   └── weekly-review.md             ← Sunday 10 AM weekly review
├── infrastructure/
│   ├── README.md                    ← EC2 server ops reference
│   ├── terraform/                   ← AWS infrastructure as code
│   └── docker/                      ← Docker compose + bootstrap scripts
├── settings/
│   └── README.md                    ← Settings reference (no secrets committed)
└── scripts/
    ├── health-check.sh
    ├── ssm-mcp-tunnel.sh
    └── sync-nextcloud-to-openproject.sh
```

---

## Team Setup Guide

> **For new team members** — see the full step-by-step guide: **[mcp-servers/TEAM-INSTALL.md](mcp-servers/TEAM-INSTALL.md)**

Quick summary:

### Prerequisites

Install these before starting:

```bash
# Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Node.js + npm
brew install node

# uv (Python package manager — faster than pip)
brew install uv

# Claude CLI
npm install -g @anthropic/claude-code

# AWS CLI (for S3 and infrastructure access)
brew install awscli
```

You also need:
- **Claude Desktop** — download from https://claude.ai/download
- **Kiro** — download from https://kiro.dev (optional, for IDE integration)

---

### Step 1 — Clone this repo

```bash
git clone <repo-url> ~/.claude-assistant
cd ~/.claude-assistant
```

---

### Step 2 — Register local MCP servers with Claude CLI

This registers the servers that run on your Mac (stdio transport):

```bash
bash mcp-servers/install-all.sh
```

Verify:
```bash
claude mcp list
```

You should see `google-workspace`, `whatsapp`, `document-loader`, `filesystem`, `playwright`, `aws-s3-local` all listed.

---

### Step 3 — Connect to the AXINA remote MCP server

The remote MCP server runs on EC2 at `projects.axinagroup.com`. It gives Claude access to OpenProject and S3 from anywhere — including mobile.

**Get the API key from a current team member** (stored in 1Password under `AXINA MCP API Key` or ask Daniel).

Then register it:

```bash
# Replace <KEY> with the actual key
claude mcp add --transport sse --scope user openproject-remote \
  "https://projects.axinagroup.com/mcp/sse?key=<KEY>"
```

Test it:
```bash
claude mcp list
# openproject-remote should show ✓ Connected (may take a few seconds)
```

Then in any Claude session:
> *"List my OpenProject projects"*

---

### Step 4 — Configure Claude Desktop

Update `~/Library/Application Support/Claude/claude_desktop_config.json` with the full server list. Use the template below — replace `<MCP_API_KEY>` with the team key:

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

Restart Claude Desktop after saving.

---

### Step 5 — Set up WhatsApp MCP (optional)

The WhatsApp server requires a local bridge running on your Mac.

```bash
git clone https://github.com/lharries/whatsapp-mcp ~/whatsapp-mcp
cd ~/whatsapp-mcp/whatsapp-mcp-server
uv sync
python main.py   # scan the QR code with WhatsApp on your phone
```

Once paired, stop the process — Claude will start it automatically via the MCP config.

---

### Step 6 — Configure Kiro IDE (optional)

If you use Kiro, add the AXINA MCP server to `~/.kiro/settings/mcp.json`:

```json
{
  "mcpServers": {
    "axina-mcp": {
      "command": "uvx",
      "args": [
        "mcp-proxy@latest",
        "https://projects.axinagroup.com/mcp/sse?key=<MCP_API_KEY>"
      ],
      "env": {}
    }
  }
}
```

Reload Kiro MCP servers: **Cmd+Shift+P → "Kiro: Reload MCP Servers"**

You should see 8 tools appear: `list_projects`, `get_project`, `create_work_package`, `list_work_packages`, `list_s3_buckets`, `list_s3_objects`, `get_s3_object`, `search_s3_objects`.

---

### Step 7 — Load scheduled tasks into Claude Desktop (optional)

Prompts live in `scheduled-tasks/`. To activate:

1. Open **Claude Desktop**
2. **Schedule** (sidebar) → **+ New task**
3. Paste the prompt from the relevant `.md` file
4. Set schedule and click **Run once** to test

| File | Schedule | What it does |
|------|----------|--------------|
| `morning-briefing.md` | Weekdays 7:00 AM ET | Scans Gmail, calendar, Drive; writes brief; sends WhatsApp |
| `evening-wrap-up.md` | Weekdays 6:00 PM ET | Reviews sent mail, open tasks, tomorrow's agenda |
| `weekly-review.md` | Sundays 10:00 AM ET | Cross-org rollup across 4ward / XGC / AXINA |

Requires `google-workspace` and `whatsapp` MCP servers to be connected.

---

### Step 8 — Verify everything

```bash
bash scripts/health-check.sh
```

Or manually:
```bash
claude mcp list                          # all servers listed
claude "List my OpenProject projects"    # remote MCP working
```

---

## MCP Server Quick Reference

| Server | Transport | Where It Runs | What It Does |
|--------|-----------|--------------|--------------|
| `google-workspace` | stdio | Mac | Gmail, Calendar, Drive, Tasks |
| `whatsapp` | stdio | Mac | WhatsApp outbound messages |
| `document-loader` | stdio | Mac | Read PDF/Office files |
| `filesystem` | stdio | Mac | Documents, Downloads, Desktop |
| `playwright` | stdio | Mac | Browser automation |
| `aws-s3-local` | stdio | Mac | S3 file access (CLI use) |
| `openproject-remote` | SSE | EC2 | OpenProject + S3 (works anywhere) |

---

## Remote MCP Server

The AXINA remote MCP server runs on EC2 at `projects.axinagroup.com/mcp/`.

- **Health check:** `curl https://projects.axinagroup.com/mcp/health`
- **SSE endpoint:** `https://projects.axinagroup.com/mcp/sse?key=<KEY>`
- **Tools:** OpenProject (list/create projects and work packages) + S3 (list/search/read files)
- **Auth:** API key in URL query param `?key=` or `X-MCP-Key` header
- **Infra:** See `infrastructure/README.md` for EC2/Docker/nginx details

---

## Security

- Never commit API keys, tokens, or `.env` files
- The MCP API key is in 1Password: **AXINA MCP API Key**
- The `openproject-mcp/.env` file is in `.gitignore`
- See `settings/README.md` for the full security checklist
