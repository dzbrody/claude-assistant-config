# Claude Personal Assistant — CTO Rescues Infrastructure

A complete AI-powered personal assistant ecosystem built with Claude Code and Claude CLI. Runs morning briefings, evening wrap-ups, weekly reviews, and real-time OpenProject notifications — all from a native Mac menu bar app with one click.

> **Author**: Daniel Brody (@dzbrody) — [ctorescues.com](https://ctorescues.com/)  
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
| [RELEASE-NOTES-v2.0.md](RELEASE-NOTES-v2.0.md) | Full changelog for the June 11 2026 release (v2.0.0) |
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
- Scans last 24h across **8 core WhatsApp groups** (TSPG, TGI Tech, Angola, Uganda, Dev, TGI Geneses, AXINOD UKR, Erin Davidson) — downloads docs to Drive, creates OpenProject tasks
- Scans **10 NCR Africa WhatsApp groups** — enforces weekly touchpoint rule, prompts y/N before sending nudge messages (never auto-sends)
- Scans all Gmail in the last 24h, auto-creates OpenProject tasks for action items
- Extracts tasks from Gemini meeting notes (`gemini-notes@google.com`) and Zoom AI summaries → OpenProject
- Auto-closes OpenProject tasks when completion is confirmed in messages or email
- Links relevant Drive documents to newly created tasks via Drive file ID
- Reviews today's calendar, flags conflicts
- Writes daily brief to `db@xgccorp.com → My Drive → _daily_brief/YYYY-MM-DD.md`
- Sends WhatsApp summary to your number

**CLI command matrix** (`/pmo-*` triggers, run from the terminal at any time):

| Command | What it does |
|---------|-------------|
| `/transcribe` | Transcribe audio/video from S3 or a Google Drive / Meet URL via EC2 Whisper |
| `/ingest-meeting-notes` | Fetch `gemini-notes@google.com`, filter by Axina context, create OP tasks |
| `/pmo-dedup` | Detect and merge duplicate work packages across all projects |
| `/pmo-track-time` | Match calendar events to OP tasks and log time entries |
| `/pmo-sweep-completed` | Auto-close 100%-done or all-children-closed tasks |
| `/pmo-schedule-focus` | Book "PMO Focus Block" calendar slots for top-priority tasks |
| `/pmo-clean-backlog` | Triage tasks missing assignee, start date, or due date |

Run `/pmo-menu` to see the full reference table.

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
| `whatsapp` | local Python + Go bridge (v0.3.0, Bearer auth) | WhatsApp messages and media |
| `filesystem` | `@modelcontextprotocol/server-filesystem` | Drive, Documents, OneDrive |
| `document-loader` | `uvx markitdown-mcp` | Read PDF/Office files |
| `aws-s3-local` | `@iflow-mcp/samuraikun-aws-s3-mcp` | S3 file access |
| `playwright` | `@playwright/mcp@latest` | Browser automation |

### Remote Server (SSE — works from any device)

| Server | Endpoint | Tools |
|--------|----------|-------|
| `openproject-remote` | `https://projects.axinagroup.com/mcp/sse` | 49 tools across work packages, projects, users, memberships, hierarchy, relations, time entries, versions, weekly reports, news |

API key stored in 1Password as **CTO Rescues MCP API Key**. Server: Python 3.12, FastMCP 3.4.2, SSE transport, EC2 IAM role for S3. Source: `mcp-servers/openproject-mcp/`.

### VDR (Virtual Data Room)

| Service | URL | Status |
|---------|-----|--------|
| Papermark | `https://vdr.axinagroup.com` | Deploying — build in progress |

Managed via MCP tools `create_secure_dataroom`, `issue_vdr_access_link`, `list_datarooms` (tools 50–52 in the remote MCP server). See `docs/papermark-self-hosted-deployment.md` for full deployment notes including aarch64 build constraints.

---

## Scheduled Briefings

| Task | Button | Typical Runtime |
|------|--------|----------------|
| Morning Briefing | ☀️ | ~12–15 min |
| Evening Wrap-Up | 🌙 | ~5–7 min |
| Weekend Briefing | 📅 | ~8–10 min |
| Weekly Review | 📊 | ~5–8 min |

Runs via `scripts/run-scheduled-task.sh` — streams output live, captures for email summary.
Output: `db@xgccorp.com → My Drive → _daily_brief/YYYY-MM-DD.md`

WhatsApp summary sent to Daniel's number at the end of every run.

---

## Infrastructure

### AWS Resources

| Resource | Detail |
|----------|--------|
| EC2 | `t4g.xlarge` (4 vCPU, 16GB RAM, Graviton2 arm64), Amazon Linux 2023, 30GB root + 100GB data |
| Instance ID | `i-07bb8581203e52527`, AZ `us-east-1f` |
| Domain | `projects.axinagroup.com` (Route53) |
| SSL | Let's Encrypt via Certbot (auto-renewing, expires 2026-09-12) |
| Email | SES SMTP `no-reply@axinagroup.com` |
| Storage | S3 `axina-openproject-files` (versioned, SSE-S3) |

### Docker Containers on EC2

| Container | Purpose |
|-----------|---------|
| `openproject-app` | Project management UI (OpenProject 17.4.1) |
| `openproject-postgres` | PostgreSQL 16 database (shared with Papermark) |
| `openproject-nginx` | Reverse proxy + SSL termination (projects + vdr subdomains) |
| `openproject-certbot` | Let's Encrypt auto-renewal |
| `openproject-hocuspocus` | Real-time collaborative editing |
| `openproject-cache` | Memcached (Rails cache) |
| `openproject-mcp-server` | Remote MCP endpoint — 52-tool FastMCP server (SSE, :39128 internal) |
| `papermark-app` | Virtual Data Room — `vdr.axinagroup.com` (in progress — build active) |

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

---

© 2026 **Yom Shore Ventures LLC**  
dba: *CTO Rescues* — [ctorescues.com](https://ctorescues.com/)  
**Author:** Daniel Brody (@dzbrody)  
**Registered Address:** 8 The Green – Suite 12060, Dover, Delaware 19901, United States  
*All rights reserved. Unauthorized copying, modification, or distribution is strictly prohibited.*
