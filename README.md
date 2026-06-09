# Claude Personal Assistant — AXINA Group Infrastructure

A complete AI-powered personal assistant ecosystem built with Claude Code and Claude CLI. Runs morning briefings, evening wrap-ups, weekly reviews, and real-time OpenProject notifications — all from a native Mac menu bar app with one click.

> **Author**: dzbrody  
> **Infrastructure**: AWS us-east-1  
> **Status**: Active

---

## Table of Contents

- [What This Does](#what-this-does)
- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Quick Start](#quick-start)
- [Desktop App](#desktop-app)
- [MCP Server Ecosystem](#mcp-server-ecosystem)
- [Scheduled Briefings](#scheduled-briefings)
- [Infrastructure](#infrastructure)
- [Security Design](#security-design)

### Sub-documentation

| File | Contents |
|------|----------|
| [desktop/README.md](desktop/README.md) | Menu bar app install, accessibility setup, AWS session, CLI usage, logs |
| [mcp-servers/TEAM-INSTALL.md](mcp-servers/TEAM-INSTALL.md) | Full 12-step new user setup guide — start here for a fresh Mac |
| [mcp-servers/README.md](mcp-servers/README.md) | MCP server inventory, WhatsApp architecture, add/remove servers |
| [scheduled-tasks/README.md](scheduled-tasks/README.md) | Briefing prompts, document saving rules, TSPG group config |
| [scripts/README.md](scripts/README.md) | OpenProject notifier config, background service management |
| [infrastructure/README.md](infrastructure/README.md) | Terraform deployment, EC2 operations, Docker containers |
| [axerp-openproject/](axerp-openproject/) | AXERP & AWS project hierarchy docs for OpenProject wiki |

---

## What This Does

**Click ☀️ in the menu bar** → Terminal opens, claude launches, the full morning briefing runs automatically:
- Scans last 24h of messages across 8 WhatsApp groups (TSPG, TGI Tech, Angola, Uganda, Dev, Marketing, AXINOD UKR, Erin Davidson), downloads and saves documents to Google Drive, creates OpenProject work packages for action items
- Scans all Gmail in the last 24h, flags urgent items from AXINA/XGC/4ward domains, auto-creates OpenProject tasks for action items
- Extracts tasks from Gemini meeting notes and Zoom AI summaries → OpenProject
- Scans 10 NCR Africa WhatsApp groups, enforces weekly touchpoint rule, drafts nudge messages for review
- Auto-closes OpenProject tasks when completion is indicated in messages or email
- Links relevant Drive documents to newly created tasks
- Reviews today's calendar, flags conflicts
- Writes daily brief to `db@xgccorp.com → My Drive → _daily_brief/YYYY-MM-DD.md`
- Sends a WhatsApp summary to your number

**Click 🌙** → Evening wrap-up: sent emails, Drive activity, TSPG afternoon messages, task status, tomorrow preview.

**Click 📅 / 📊** → Weekend briefing and weekly review on Sundays.

**Always running in background** → OpenProject notifier posts every new task, status change, and assignment to the TSPG WhatsApp group every 15 minutes.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         YOUR MAC                                │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  🤖 Claude Assistant (menu bar app)                     │    │
│  │  python3.12 + rumps                                     │    │
│  │  Copies prompt → opens Terminal → launches claude CLI   │    │
│  └────────────────────────┬───────────────────────────────┘    │
│                           │                                     │
│  ┌────────────────────────▼───────────────────────────────┐    │
│  │  claude CLI (interactive, --dangerously-skip-permissions)│    │
│  │  Runs from ~/.claude-assistant                           │    │
│  │  Reads MCP config from .claude/settings.local.json      │    │
│  └────────────────────────┬───────────────────────────────┘    │
│                           │  MCP (stdio + SSE)                  │
│  ┌────────────────────────▼───────────────────────────────┐    │
│  │  Local MCP Servers                                       │    │
│  │  • google-workspace  (Gmail, Calendar, Tasks, Drive)    │    │
│  │  • whatsapp          (via Go bridge on :8080)           │    │
│  │  • filesystem        (Drive, Documents, OneDrive)       │    │
│  │  • document-loader   (PDF, Office files)                │    │
│  │  • aws-s3-local      (S3 file access)                   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Background Services (launchd — start at login)          │    │
│  │  • whatsapp-bridge       Go, :8080, persistent session  │    │
│  │  • openproject-notifier  Python, every 15 min           │    │
│  │  • claude-assistant app  Python 3.12 menu bar           │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────┬───────────────────────────────────────┘
                          │ HTTPS + API Key
┌─────────────────────────▼───────────────────────────────────────┐
│  AWS EC2 (us-east-1)                                            │
│  • OpenProject (Docker) — projects.axinagroup.com               │
│  • Remote MCP Server (SSE) — OpenProject + S3 tools             │
│  • S3: xgccloud-openproject-files                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
~/.claude-assistant/
├── README.md
├── .claude/
│   ├── settings.local.json.example  # Template — copy to settings.local.json, fill in keys
│   └── settings.local.json          # ⚠️ gitignored — contains MCP API keys and personal paths
│
├── desktop/                        # Menu bar app
│   ├── app.py                     # rumps app — 🤖 in menu bar
│   ├── build.sh                   # Package as .app, install LaunchAgent
│   ├── run_briefing.sh            # Shell wrapper — AWS check → launch claude
│   └── README.md
│
├── scheduled-tasks/                # Briefing prompts
│   ├── morning-briefing.md        # Full morning briefing — 8 WhatsApp groups, 10 NCR groups
│   ├── evening-wrap-up.md
│   ├── weekend-briefing.md
│   ├── weekly-review.md
│   └── README.md
│
├── axerp-openproject/              # AXERP project hierarchy for OpenProject wiki
│   ├── PROJECT_HIERARCHY.md       # All OpenProject project definitions
│   └── wiki/                      # Technical specs (AXERP, AWS, Blockchain, API, Onboarding)
│
├── mcp-servers/                    # MCP server config and install
│   ├── install-all.sh             # Register all local servers with claude CLI
│   ├── TEAM-INSTALL.md            # Full setup guide for new team members
│   ├── README.md
│   └── remote-mcp-server/
│       ├── server.py              # FastAPI SSE server (OpenProject + S3)
│       └── Dockerfile
│
├── scripts/                        # Background services and utilities
│   ├── openproject-whatsapp-notifier.py
│   ├── health-check.sh
│   └── README.md
│
└── infrastructure/                 # AWS Terraform + Docker
    ├── terraform/
    └── docker/
```

---

## Quick Start

Full instructions: **[mcp-servers/TEAM-INSTALL.md](mcp-servers/TEAM-INSTALL.md)**

```bash
# 1. Install prerequisites
brew install node uv awscli python@3.12 go
npm install -g @anthropic/claude-code
/usr/local/bin/pip3.12 install rumps --break-system-packages

# 2. Clone
git clone <repo-url> ~/.claude-assistant

# 3. Register MCP servers
bash ~/.claude-assistant/mcp-servers/install-all.sh

# 4. Add remote MCP (key from 1Password: "AXINA MCP API Key")
# Note: this is stored in .claude/settings.local.json (gitignored).
# Copy .claude/settings.local.json.example → .claude/settings.local.json and fill in your key,
# or run this command to register it via the CLI:
claude mcp add --transport sse --scope user openproject-remote \
  "https://projects.axinagroup.com/mcp/sse?key=<KEY>"

# 5. Set up WhatsApp bridge
git clone https://github.com/lharries/whatsapp-mcp ~/whatsapp-mcp
cd ~/whatsapp-mcp/whatsapp-bridge && go build -o whatsapp-bridge .
# Run it once, scan QR code on your phone, then install as launchd service

# 6. Install the menu bar app
bash ~/.claude-assistant/desktop/build.sh
# Answer y to start at login

# 7. Grant accessibility: System Settings → Privacy & Security → Accessibility → add Terminal

# 8. Configure AWS SSO
aws sso login --profile xgc-main
```

---

## Desktop App

The menu bar app (`desktop/`) is the primary way to run briefings. It:

1. Copies the full prompt to the clipboard
2. Opens a new Terminal window
3. Launches `claude --dangerously-skip-permissions`
4. Waits 8 seconds for claude + MCP servers to load
5. Pastes via Cmd+V, presses Enter
6. Claude runs fully interactively — output streams live

**Why interactive mode?** Claude's MCP tool calls require a real TTY. The `-p` non-interactive flag silently produces no output when MCP tools are involved due to output buffering.

See **[desktop/README.md](desktop/README.md)** for full installation details.

---

## MCP Server Ecosystem

### Local Servers (stdio)

| Server | Package | What It Does |
|--------|---------|-------------|
| `google-workspace` | `@alanxchen/google-workspace-mcp` | Gmail, Calendar, Drive, Tasks |
| `whatsapp` | local Python + Go bridge | WhatsApp messages and media |
| `filesystem` | `@modelcontextprotocol/server-filesystem` | Drive, Documents, OneDrive |
| `document-loader` | `uvx markitdown-mcp` | Read PDF/Office files |
| `aws-s3-local` | `@iflow-mcp/samuraikun-aws-s3-mcp` | S3 file access |
| `playwright` | `@playwright/mcp@latest` | Browser automation for web tasks |

### Remote Server (SSE — works from any device)

| Server | Endpoint | Tools |
|--------|----------|-------|
| `openproject-remote` | `https://projects.axinagroup.com/mcp/sse` | `list_projects`, `create_work_package`, `list_work_packages`, `list_s3_buckets`, `list_s3_objects`, `get_s3_object`, `search_s3_objects` |

API key stored in 1Password as **AXINA MCP API Key**.

---

## Scheduled Briefings

| Task | Button | Typical Runtime |
|------|--------|----------------|
| Morning Briefing | ☀️ | ~12–15 min |
| Evening Wrap-Up | 🌙 | ~5–7 min |
| Weekend Briefing | 📅 | ~8–10 min |
| Weekly Review | 📊 | ~5–8 min |

Output: `db@xgccorp.com → My Drive → _daily_brief/YYYY-MM-DD.md`

WhatsApp summary sent to Daniel's number at the end of every run.

---

## Infrastructure

### AWS Resources

| Resource | Detail |
|----------|--------|
| EC2 | `t3.large`, Amazon Linux 2023, 30GB root + 100GB data |
| Domain | `projects.axinagroup.com` (Route53) |
| SSL | Let's Encrypt via Certbot (auto-renewing) |
| Email | SES SMTP `no-reply@axinagroup.com` |
| Storage | S3 `xgccloud-openproject-files` (versioned, SSE-S3) |

### Docker Containers on EC2

| Container | Purpose |
|-----------|---------|
| `openproject-app` | Project management UI |
| `openproject-postgres` | Database |
| `openproject-nginx` | Reverse proxy + SSL |
| `openproject-certbot` | SSL renewal |
| `openproject-mcp-server` | Remote MCP endpoint (SSE, :39128 internal) |

---

## Security Design

- MCP server binds to `127.0.0.1:39128` only — all access via nginx HTTPS
- 64-char hex API key required on all `/mcp` endpoints
- No SSH port open — EC2 management via AWS SSM only
- No hardcoded secrets — credentials in `.env` (chmod 600) on server, 1Password / macOS Keychain locally
- S3: SSE-S3, public access blocked, CORS restricted to `projects.axinagroup.com`
- WhatsApp bridge binds to `127.0.0.1:8080` only
- `.gitignore` excludes `.env`, tokens, `settings.local.json` (MCP API key), `daily_briefs/` (operational output), and private contacts
- `.claude/settings.local.json.example` provides a redacted template for onboarding new team members

---

## Acknowledgments

- [OpenProject](https://www.openproject.org/) — Open-source project management
- [Anthropic](https://www.anthropic.com/) — Claude AI and Claude Code
- [lharries/whatsapp-mcp](https://github.com/lharries/whatsapp-mcp) — WhatsApp MCP bridge
- [Model Context Protocol](https://modelcontextprotocol.io/) — MCP specification
