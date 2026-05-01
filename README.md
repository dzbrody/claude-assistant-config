# Claude Personal Assistant — AXINA Group Infrastructure

A complete AI-powered personal assistant ecosystem built with Claude Code, Claude Desktop, and Claude Mobile. This project provisions and manages all infrastructure, MCP servers, scheduled automations, and project management tooling for AXINA Group and its subsidiary organizations (4ward.earth, XGC).

> **Author**: dzbrody
> **Infrastructure**: AWS us-east-1
> **Status**: Active

---

## Table of Contents

- [What This Project Does](#what-this-project-does)
- [Architecture Overview](#architecture-overview)
- [Project Structure](#project-structure)
- [Core Capabilities](#core-capabilities)
- [Infrastructure](#infrastructure)
- [MCP Server Ecosystem](#mcp-server-ecosystem)
- [Scheduled Automations](#scheduled-automations)
- [Quick Start](#quick-start)
- [Security Design](#security-design)
- [License](#license)

---

## What This Project Does

This repository is the complete configuration, infrastructure-as-code, and documentation for using Claude AI as a personal executive assistant.

**Every morning at 7:00 AM**, Claude scans overnight emails, reviews the day's calendar, flags urgent items, creates Google Calendar tasks, saves a structured briefing to `~/Documents/daily_briefs/`, and sends a summary via WhatsApp.

**Throughout the day**, Claude manages projects in OpenProject, searches files across S3 and local storage, and coordinates work across three organizations (4ward.earth, XGC, AXINA).

**Every evening at 6:00 PM**, Claude compiles a wrap-up: emails sent, meetings attended, files modified, tasks completed, and a preview of tomorrow.

**Every Sunday**, Claude generates a weekly review aggregated by organization with week-over-week comparisons.

All of this runs on AWS infrastructure defined as Terraform and deployed with Docker Compose.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         YOUR MAC                                │
│                                                                 │
│  ┌─────────────────────────┐    ┌──────────────────────────┐   │
│  │    Claude Desktop        │    │    Claude Code CLI       │   │
│  │  (UI + Scheduled Tasks)  │    │  (Terminal + Cowork)     │   │
│  └──────────┬──────────────┘    └──────────┬───────────────┘   │
│             │                              │                    │
│             │    Local MCP Servers (stdio)  │                    │
│             ├──────────────────────────────┤                    │
│             │  • google-workspace          │                    │
│             │  • whatsapp                  │                    │
│             │  • filesystem                │                    │
│             │  • document-loader           │                    │
│             │  • playwright                │                    │
│             │  • aws-s3-local              │                    │
│             └──────────────────────────────┘                    │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Background Services (launchd — start at login)          │   │
│  │  • whatsapp-bridge (Go) — persistent WhatsApp session    │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                    HTTPS (443) + API Key
                              │
┌─────────────────────────────┴───────────────────────────────────┐
│                    AWS us-east-1 (EC2)                           │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Docker Containers                                       │    │
│  │                                                         │    │
│  │  ┌──────────┐ ┌─────────┐ ┌──────────┐ ┌──────────┐   │    │
│  │  │OpenProject│ │PostgreSQL│ │ Memcached│ │  Nginx   │   │    │
│  │  │  :8080   │ │ :5432   │ │ :11211   │ │:80/:443  │   │    │
│  │  └──────────┘ └─────────┘ └──────────┘ └────┬─────┘   │    │
│  │                                              │          │    │
│  │  ┌──────────┐                    ┌───────────┴──────┐   │    │
│  │  │ Certbot  │                    │  Remote MCP Server│   │    │
│  │  │SSL renew │                    │  (SSE) :39128    │   │    │
│  │  └──────────┘                    │  • OpenProject   │   │    │
│  │                                  │  • AWS S3        │   │    │
│  │                                  └──────────────────┘   │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  AWS Services                                            │    │
│  │  • Route53: projects.axinagroup.com                     │    │
│  │  • SES: SMTP email (no-reply@axinagroup.com)            │    │
│  │  • S3: xgccloud-openproject-files (attachments, backups)│    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                    HTTPS (443) + API Key
                              │
┌─────────────────────────────┴───────────────────────────────────┐
│                    CLAUDE MOBILE                                 │
│  (Connect from anywhere — same remote MCP server)               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
~/.claude-assistant/
├── README.md                           # This file
├── .gitignore                          # Secrets, .env, tokens excluded
│
├── infrastructure/                     # AWS Infrastructure as Code
│   ├── terraform/
│   │   ├── main.tf                     # EC2, Security Group, EIP, Route53, S3, IAM
│   │   ├── variables.tf                # All configurable values
│   │   └── outputs.tf                  # Connection strings, instance IDs
│   ├── docker/
│   │   ├── user-data.sh               # EC2 bootstrap (Docker, nginx, SSL, MCP)
│   │   ├── post-bootstrap.sh          # MCP server setup after first login
│   │   └── .env.example               # Environment variable template (no secrets)
│   └── README.md                      # Deployment and operations guide
│
├── mcp-servers/                        # MCP Server Configurations
│   ├── README.md                      # Complete server inventory + WhatsApp arch
│   ├── TEAM-INSTALL.md                # Step-by-step new user setup guide
│   ├── install-all.sh                 # One-command install for all local servers
│   └── remote-mcp-server/
│       ├── server.py                  # Custom Remote MCP server (OpenProject + S3)
│       └── Dockerfile                 # Container definition
│
├── scheduled-tasks/                    # Claude Desktop Scheduled Task Prompts
│   ├── README.md                      # How to load + WhatsApp prerequisites
│   ├── morning-briefing.md            # 7:00 AM weekday briefing
│   ├── evening-wrap-up.md             # 6:00 PM weekday wrap-up
│   └── weekly-review.md               # Sunday 10:00 AM weekly review
│
├── scripts/                            # Utility Scripts
│   ├── health-check.sh                # Verify all MCP servers and directories
│   ├── ssm-mcp-tunnel.sh             # SSM tunnel for secure MCP access
│   ├── sync-nextcloud-to-openproject.sh  # NextCloud → S3 migration
│   └── decommission-nextcloud.sh      # NextCloud cleanup
│
└── settings/                           # Reference Configuration
    └── README.md                      # Settings documentation
```

---

## Core Capabilities

### AI Assistant Features
- **Daily Briefings**: Email scanning, calendar review, task creation, WhatsApp delivery
- **Evening Wrap-Ups**: Sent email summaries, file change tracking, next-day preview
- **Weekly Reviews**: Cross-organization aggregation with week-over-week comparisons
- **File Intelligence**: Search S3 buckets, local documents, OneDrive, and Google Drive
- **Browser Automation**: Web scraping and automated web interactions via Playwright
- **Multi-Organization**: Separate tracking for 4ward.earth, XGC, and AXINA

### File Storage & Search
- **Local Files**: Controlled access to Desktop, Documents, Downloads
- **S3 Storage**: OpenProject attachments + file search
- **Google Drive**: Deep search and document editing via OAuth MCP

### Communication
- **Email**: Full Gmail integration (read, search, send)
- **Calendar**: Google Calendar management with task creation
- **Messaging**: WhatsApp send/receive via Go bridge + Python MCP server
- **Notifications**: SES SMTP for system emails (`no-reply@axinagroup.com`)

### Project Management
- **OpenProject**: Self-hosted at `projects.axinagroup.com` with 8 remote MCP tools
- **GitHub Integration**: PR linking, branch creation snippets, status tracking
- **Projects**: AXINA Group Admin, AXERP, AXINA Group Website

---

## Infrastructure

### AWS Resources

| Resource | Detail |
|----------|--------|
| **EC2** | `t3.large`, Amazon Linux 2023, EBS gp3 (30GB root + 100GB data) |
| **Domain** | `projects.axinagroup.com` (Route53 hosted zone: `axinagroup.com`) |
| **DNS** | Route53 A record → Elastic IP |
| **SSL** | Let's Encrypt via Certbot (auto-renewing) |
| **Email** | SES SMTP (`email-smtp.us-east-1.amazonaws.com`) |
| **Storage** | S3 bucket `xgccloud-openproject-files` (SSE-S3, versioned, CORS) |
| **Backup** | Daily API-pulled backups to S3 with 30-day lifecycle |
| **IAM** | `axina-openproject-role` with S3 + SSM policies |
| **Instance ID** | `terraform output instance_id` |
| **Elastic IP** | `terraform output public_ip` |

### Docker Containers (EC2)

| Container | Image | Port | Purpose |
|-----------|-------|------|---------|
| `openproject-app` | `openproject/openproject:17` | 8080 (internal) | Project management |
| `openproject-postgres` | `postgres:14` | 5432 (internal) | Database |
| `openproject-cache` | `memcached:alpine` | 11211 (internal) | Rails cache |
| `openproject-nginx` | `nginx:alpine` | 80/443 (public) | Proxy + SSL |
| `openproject-certbot` | `certbot/certbot` | — | SSL auto-renewal |
| `openproject-mcp-server` | Custom Python 3.11 | 39128 (internal) | Remote MCP endpoint |

---

## MCP Server Ecosystem

### Local Servers (Mac — stdio transport)

| Server | Command | Purpose |
|--------|---------|---------|
| `google-workspace` | `npx @alanxchen/google-workspace-mcp` | Gmail, Calendar, Tasks |
| `whatsapp` | `uv run main.py` (requires Go bridge) | WhatsApp messaging |
| `document-loader` | `npx @anthropic/mcp-document-loader` | Read PDF, Word, Excel |
| `filesystem` | `npx @modelcontextprotocol/server-filesystem` | Desktop/Documents/Downloads |
| `playwright` | `npx @anthropic-ai/mcp-server-playwright` | Browser automation |
| `aws-s3-local` | `npx @iflow-mcp/samuraikun-aws-s3-mcp` | S3 operations (CLI) |

### Remote Server (EC2 — SSE transport, API key required)

| Server | Endpoint | Tools |
|--------|----------|-------|
| `openproject-remote` | `https://projects.axinagroup.com/mcp/sse` | `list_projects`, `get_project`, `create_work_package`, `list_work_packages`, `list_s3_buckets`, `list_s3_objects`, `get_s3_object`, `search_s3_objects` |

### WhatsApp Architecture

WhatsApp requires two components on your Mac:

```
Claude → whatsapp-mcp-server (Python, stdio)
              │  HTTP :8080
              ▼
         whatsapp-bridge (Go, launchd service)   ← persistent session
              │  WebSocket
              ▼
         WhatsApp servers
```

The Go bridge runs as a **launchd background service** (starts at login, restarts on crash). The QR code link is **one-time only** — the session persists in `~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db`. The 8 AM briefing sends WhatsApp messages automatically with no manual intervention.

```bash
# Check bridge status anytime
curl http://localhost:8080/api/health
# → {"connected":true,"status":"ok","timestamp":...}
```

See `mcp-servers/TEAM-INSTALL.md` for full setup including launchd service installation.

### Connection Reference

```bash
# Register remote MCP with Claude CLI
claude mcp add --transport sse --scope user openproject-remote \
  "https://projects.axinagroup.com/mcp/sse?key=<MCP_API_KEY>"

# Kiro IDE — add to ~/.kiro/settings/mcp.json
"axina-mcp": {
  "command": "uvx",
  "args": ["mcp-proxy@latest", "https://projects.axinagroup.com/mcp/sse?key=<MCP_API_KEY>"],
  "env": {}
}

# Claude Mobile: Settings → MCP Servers → https://projects.axinagroup.com/mcp/sse?key=<KEY>
```

MCP API key is stored in 1Password as **AXINA MCP API Key**.

---

## Scheduled Automations

| Task | Schedule | What It Does |
|------|----------|-------------|
| **Morning Briefing** | Weekdays, 7:00 AM ET | Scan email since 5 PM, review calendar, flag urgent items, create Google Tasks, write briefing file, send WhatsApp summary |
| **Evening Wrap-Up** | Weekdays, 6:00 PM ET | Sent emails, meetings attended, files modified, tomorrow's preview, WhatsApp wrap-up |
| **Weekly Review** | Sundays, 10:00 AM ET | Aggregate all daily briefs by org (4ward / XGC / AXINA), flag stale tasks, WhatsApp summary |

All briefings are saved to `~/Documents/daily_briefs/YYYY-MM-DD.md`.

Prompts live in `scheduled-tasks/`. Load via Claude Desktop → Schedule → + New task. The WhatsApp Go bridge must be running as a launchd service for automated delivery. See `scheduled-tasks/README.md`.

---

## Quick Start

### Prerequisites
- macOS 13 or later
- Anthropic account (claude.ai)
- Access to AXINA team 1Password vault (MCP API key)
- AWS CLI configured (`aws sso login --profile xgc-main`)
- Terraform (`brew install terraform`)
- Go (`brew install go`) — for WhatsApp bridge
- SSH key: `aws-key-xgccloudcom`

### New Team Member Setup

Full step-by-step instructions: **[mcp-servers/TEAM-INSTALL.md](mcp-servers/TEAM-INSTALL.md)**

Quick summary:
```bash
# 1. Install tools
brew install node uv awscli go
npm install -g @anthropic/claude-code

# 2. Clone repo
git clone https://github.com/dzbrody/claude-assistant-config.git ~/.claude-assistant

# 3. Register local MCP servers
bash ~/.claude-assistant/mcp-servers/install-all.sh

# 4. Add remote MCP server (get key from 1Password: "AXINA MCP API Key")
claude mcp add --transport sse --scope user openproject-remote \
  "https://projects.axinagroup.com/mcp/sse?key=<KEY>"

# 5. Set up WhatsApp (see TEAM-INSTALL.md Step 5 for full detail)
git clone https://github.com/lharries/whatsapp-mcp ~/whatsapp-mcp
cd ~/whatsapp-mcp/whatsapp-bridge && go build -o whatsapp-bridge .
# → scan QR once, then install as launchd service

# 6. Verify
claude mcp list
curl http://localhost:8080/api/health
```

### Infrastructure Deployment (new server)

```bash
cd ~/.claude-assistant/infrastructure/terraform
terraform init
terraform plan
terraform apply

# After EC2 boots, complete MCP setup
aws ssm start-session --target <instance-id>
echo "OPENPROJECT_ADMIN_API_KEY=<token>" >> /opt/openproject/.env
echo "MCP_API_KEY=<key>" >> /opt/openproject/.env
cd /opt/openproject && docker-compose up -d --build mcp-server
```

---

## Security Design

- **MCP port never public**: The remote MCP server binds to `127.0.0.1:39128` only. All external access goes through nginx on HTTPS 443.
- **API key authentication**: All `/mcp` endpoints require a 64-character hex key in `?key=` query param or `X-MCP-Key` header. Auth is enforced in the FastAPI middleware (not nginx), so both SSE and message endpoints are protected correctly.
- **Session-based message routing**: After SSE authentication, subsequent POST requests to `/mcp/messages/?session_id=<id>` are allowed through — the session ID acts as a bearer token.
- **SSM for server access**: No SSH port open. EC2 management is via AWS SSM Session Manager.
- **No hardcoded secrets**: All credentials live in `.env` files (chmod 600) on the server, or macOS Keychain locally. Nothing committed.
- **S3 encryption**: SSE-S3 enabled. Public access blocked. CORS restricted to `projects.axinagroup.com`.
- **Let's Encrypt**: Auto-renewing SSL certificates via Certbot container.
- **IAM least privilege**: EC2 role has only S3 access to the specific bucket + SSM managed instance policy.
- **WhatsApp session isolation**: The Go bridge binds only to `127.0.0.1:8080`. Not reachable externally.

---

## License

This project is provided as a reference configuration. Use at your own discretion. The MCP servers and OpenProject are subject to their respective licenses.

---

## Acknowledgments

- [OpenProject](https://www.openproject.org/) — Open-source project management
- [Anthropic](https://www.anthropic.com/) — Claude AI
- [Model Context Protocol](https://modelcontextprotocol.io/) — MCP specification
- [lharries/whatsapp-mcp](https://github.com/lharries/whatsapp-mcp) — WhatsApp MCP bridge
- AWS — Cloud infrastructure
