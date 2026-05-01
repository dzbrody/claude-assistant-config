# Scheduled Tasks

Automated prompts that run on a schedule via Claude Desktop's Scheduled Tasks feature.

## Active Tasks

| File | Schedule | Summary |
|------|----------|---------|
| `morning-briefing.md` | Weekdays, 7:00 AM ET | Scans Gmail since 5 PM, reviews today's calendar, creates Google Tasks for action items, writes a briefing file, sends WhatsApp summary |
| `evening-wrap-up.md` | Weekdays, 6:00 PM ET | Reviews sent mail, checks task status, scans modified Drive files, previews tomorrow's calendar, sends WhatsApp wrap-up |
| `weekly-review.md` | Sundays, 10:00 AM ET | Reads all daily briefings from the past week, aggregates by org (4ward / XGC / AXINA), flags stale tasks, sends WhatsApp summary |

All output files are written to `~/Documents/daily_briefs/YYYY-MM-DD.md`.

---

## Required MCP Servers

These tasks use the following MCP servers — confirm all are connected (`claude mcp list`) before scheduling:

| Server | Used for |
|--------|---------|
| `google-workspace` | Gmail, Google Calendar, Google Tasks |
| `filesystem` | Writing briefing files to `~/Documents/daily_briefs/` |
| `whatsapp` | Sending summary messages |

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
