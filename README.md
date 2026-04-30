# Claude Personal Assistant Configuration

MCP server configuration, scheduled task prompts, and helper scripts for running Claude as an AI coworker across three organizations: **4ward.earth**, **XGC**, and **AXINA**.

## Structure

```
.claude-assistant/
├── mcp-servers/
│   ├── install-all.sh       # Install all configured MCP servers
│   └── README.md            # Server list and add/remove reference
├── scheduled-tasks/
│   ├── morning-briefing.md  # Weekday 7 AM — email scan, agenda, WhatsApp brief
│   ├── evening-wrap-up.md   # Weekday 6 PM — sent mail, task status, WhatsApp summary
│   ├── weekly-review.md     # Sunday 10 AM — cross-org weekly rollup
│   └── README.md            # How to load prompts into Claude Desktop
├── scripts/
│   └── health-check.sh      # Verify MCP servers, dirs, and task files
├── settings/
│   └── README.md            # Settings file reference (no secrets committed)
└── README.md                # This file
```

## Quick Start

```bash
# 1. Install MCP servers
bash mcp-servers/install-all.sh

# 2. Verify everything is in order
bash scripts/health-check.sh

# 3. Confirm servers are registered
claude mcp list
```

## Scheduled Tasks

Prompts live in `scheduled-tasks/`. Load them into Claude Desktop → Schedule → New Task.

| File | Schedule | What It Does |
|------|----------|--------------|
| `morning-briefing.md` | Weekdays, 7:00 AM ET | Scans Gmail, reviews calendar, creates tasks, sends WhatsApp brief |
| `evening-wrap-up.md` | Weekdays, 6:00 PM ET | Reviews sent mail, files modified, open tasks, sends WhatsApp summary |
| `weekly-review.md` | Sundays, 10:00 AM ET | Aggregates daily briefs across all three orgs, flags stale tasks |

All briefing output is written to `~/Documents/daily_briefs/`.

## MCP Servers

| Server | Purpose |
|--------|---------|
| `google-workspace` | Gmail, Calendar, Drive, Tasks |
| `whatsapp` | Outbound WhatsApp messages |
| `document-loader` | Read Office/PDF files |
| `filesystem` | `~/Documents`, Google Drive (all accounts), OneDrive |
| `playwright` | Browser automation |
| `office365-local` | Control Word/Excel/PowerPoint desktop apps (manual setup) |

See `mcp-servers/README.md` for the full filesystem path list and add/remove commands.

## Storage Layout

| Location | Account / Path | Used For |
|----------|---------------|----------|
| `~/Documents` | Local | Personal files |
| `~/Library/CloudStorage/GoogleDrive-db@xgccorp.com/My Drive` | db@xgccorp.com | XGC personal drive |
| `…/Shared drives/XGC` | db@xgccorp.com | XGC company files |
| `…/Shared drives/AXINAGRP` | db@xgccorp.com | AXINA group files |
| `…/Shared drives/CCCL` | db@xgccorp.com | CCCL files |
| `…/Shared drives/Development` | db@xgccorp.com | Dev shared drive |
| `…/Shared drives/XGC-WORKING_FILES` | db@xgccorp.com | Active working files |
| `GoogleDrive-daniel@brody.ca/My Drive` | daniel@brody.ca | Personal / 4ward.earth |
| `GoogleDrive-dzbrody99@gmail.com/My Drive` | dzbrody99@gmail.com | Personal Gmail drive |
| `OneDrive-Personal` | Personal | Personal OneDrive (in CloudStorage) |
| `~/OneDrive` | Org | Teams / synced org files (mounted at home dir) |

## Project Management

Current approach:
- **GitHub Projects** — XGC and AXINA (tied to repos)
- **OpenProject on AWS** — cross-org planning for 4ward.earth and shared initiatives (to be deployed)

## Security Note

Never commit files containing real tokens, API keys, or credentials. See `.gitignore` and `settings/README.md`.
