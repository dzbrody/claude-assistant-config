# Scheduled Tasks

Automated prompts that run on a schedule via Claude Desktop's Scheduled Tasks feature.

## Active Tasks

| File | Schedule | Summary |
|------|----------|---------|
| `morning-briefing.md` | Weekdays, 7:00 AM ET | Scans AXINA-TSPG WhatsApp group (saves docs to Drive, creates OpenProject tasks), scans Gmail, extracts Gemini meeting note tasks → OpenProject, reviews calendar, writes briefing file, sends WhatsApp summary |
| `evening-wrap-up.md` | Weekdays, 6:00 PM ET | Scans TSPG group for daytime activity, reviews sent mail, checks task status, scans modified Drive files, previews tomorrow's calendar, sends WhatsApp wrap-up |
| `weekend-briefing.md` | Sundays, 8:00 AM ET | Covers Fri 4 PM → Sun morning: TSPG WhatsApp catch-up (saves docs, creates OpenProject tasks), urgent email scan, Gemini meeting notes, weekend Drive activity, Monday preview, sends WhatsApp summary |
| `weekly-review.md` | Sundays, 10:00 AM ET | Full TSPG catch-up since Friday, reads all daily briefings, aggregates by org (4ward / XGC / AXINA), flags stale tasks, sends WhatsApp summary |

All output files are written to `~/Documents/daily_briefs/YYYY-MM-DD.md`.

---

## Background Service: OpenProject → WhatsApp Notifier

In addition to the scheduled tasks above, a **background service** runs every 15 minutes and posts OpenProject `axina-group-admin` changes directly to the TSPG WhatsApp group.

| Event | WhatsApp message |
|-------|-----------------|
| New work package created | `🆕 New Task` + subject + assignee + link |
| Status changed | `📋 OpenProject Update` + old → new status + link |
| Assignee changed | `👤 OpenProject Assignment` + who → who + link |

Every message includes a direct link: `https://projects.axinagroup.com/projects/axina-group-admin/work_packages/<id>`

**This runs automatically** as a launchd service (`com.<user>.openproject-notifier`) — starts at login, no manual steps.

```bash
# Check it's running
launchctl list | grep openproject-notifier

# View live log
tail -f ~/logs/claude-assistant/op-notifier.log

# Temporarily pause notifications
launchctl unload ~/Library/LaunchAgents/com.$USER.openproject-notifier.plist

# Resume
launchctl load ~/Library/LaunchAgents/com.$USER.openproject-notifier.plist
```

See `scripts/README.md` for full configuration options.

---

## Required MCP Servers

These tasks use the following MCP servers — confirm all are connected (`claude mcp list`) before scheduling:

| Server | Used for |
|--------|---------|
| `google-workspace` | Gmail, Google Calendar, Google Tasks |
| `filesystem` | Writing briefing files + saving WhatsApp documents to Google Drive |
| `whatsapp` | Reading TSPG group messages, downloading attachments, sending summaries |
| `openproject-remote` | Creating work packages from TSPG group activity and Gemini meeting notes |

## Required Background Services

These run independently of Claude Desktop and must be installed as launchd agents:

| Service | Plist | What it does | Interval |
|---------|-------|-------------|----------|
| `whatsapp-bridge` | `com.<user>.whatsapp-bridge.plist` | Maintains WhatsApp session so MCP tools can read/send | Persistent |
| `openproject-notifier` | `com.<user>.openproject-notifier.plist` | Posts OpenProject changes to TSPG WhatsApp group | Every 15 min |

Both are installed in `~/Library/LaunchAgents/`. See `mcp-servers/TEAM-INSTALL.md` Steps 5 and 11 for setup.

### AXINA-TSPG-TEAM group

- **Chat JID**: `120363424688758322@g.us`
- **Priority**: Highest — scanned first every morning (Step 1.5)
- **Documents saved to**: `~/Library/CloudStorage/GoogleDrive-db@xgccorp.com/Shared drives/AXINAGRP/XGC-TSPG/whatsapp-docs/`
- **Tasks created in**: OpenProject `axina-group-admin` project, prefixed `[TSPG]`
- **What gets saved**: All media types — PDFs, images, documents, audio
- **What generates tasks**: Any action item, request, or follow-up directed at Daniel or the group

### WhatsApp prerequisite

The `whatsapp` MCP server requires the **Go bridge** to be running as a background service. It must be set up once before scheduled tasks will work end-to-end. See `mcp-servers/TEAM-INSTALL.md` Step 5 for full setup.

Quick check:
```bash
curl http://localhost:8080/api/health
# Must return: {"connected":true,...}
```

The bridge runs as a launchd service (`com.<user>.whatsapp-bridge`) — it starts at login and stays running. The 8 AM scheduled briefing works automatically as long as your Mac is awake and logged in.

**The QR code scan is one-time only.** Once linked, the session persists in `~/whatsapp-mcp/whatsapp-bridge/store/whatsapp.db` across reboots and app restarts.

---

## How to Load a Task

1. Open **Claude Desktop**
2. Click **Schedule** in the left sidebar
3. Click **+ New task**
4. Open the relevant `.md` file, copy everything under the `## Prompt` heading
5. Paste into the task input
6. Set the frequency and time
7. Click **Run once** to test before enabling the schedule — this also triggers the MCP permission dialogs so you can approve tool access

---

## First-Run Permissions

On the first scheduled run, Claude Desktop will prompt you to approve each MCP tool call. Run each task manually once (**Run once**) and approve all prompts. After that, subsequent scheduled runs proceed automatically.

---

## Output Format

Each briefing file follows this structure:

```
~/Documents/daily_briefs/
├── 2026-05-01.md
├── 2026-05-02.md
└── ...
```

The `weekly-review.md` prompt reads these files to generate the Sunday rollup.
