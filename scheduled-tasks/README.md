# Scheduled Tasks

Prompts for the four automated briefings. These are run via the **🤖 Claude Assistant menu bar app** — see `../desktop/README.md` for installation.

---

## Active Tasks

| File | When | What It Does |
|------|------|-------------|
| `morning-briefing.md` | Weekdays, ~7:00 AM | Scans 8 WhatsApp groups + 10 NCR Africa groups (last 24h), downloads docs to Drive, creates/closes OpenProject tasks, links Drive docs to tasks, scans Gmail (last 24h), extracts tasks from `gemini-notes@google.com` emails and Zoom AI notes, enforces NCR weekly touchpoint rule (interactive y/N nudge dispatch — Step 7), reviews calendar, writes daily brief to Google Drive `_daily_brief/`, sends WhatsApp summary |
| `evening-wrap-up.md` | Weekdays, ~6:00 PM | Scans WhatsApp groups for daytime activity, reviews sent email, scans modified Drive files, checks open tasks, previews tomorrow, writes wrapup file, sends WhatsApp summary |
| `weekend-briefing.md` | Sundays, ~8:00 AM | Covers Fri 4 PM → Sun morning: full group catch-up, urgent email scan, Gemini notes, Drive activity, Monday preview, sends WhatsApp summary |
| `weekly-review.md` | Sundays, ~10:00 AM | Reads all daily brief files, aggregates by org (4ward / XGC / AXINA), flags stale OpenProject tasks, sends WhatsApp summary |

Briefing files are written to `db@ctorescues.com → My Drive → _daily_brief/YYYY-MM-DD.md`.

---

## Required MCP Servers

All four tasks require these MCP servers to be configured in `.claude/settings.local.json`:

| Server | Used for |
|--------|---------|
| `google-workspace` | Gmail, Google Calendar, Drive |
| `whatsapp` | 8 group + 10 NCR Africa group messages, media download, send summaries |
| `filesystem` | Save docs to Google Drive, write briefing files |
| `openproject-remote` | Create, update, close, and search work packages |
| `document-loader` | Read PDF/Office attachments |
| `playwright` | Web tasks |

The WhatsApp bridge must be running (v0.3.0+ requires Bearer token auth — token auto-generated at `~/whatsapp-mcp/whatsapp-bridge/store/.bridge-token`):
```bash
TOKEN=$(cat ~/whatsapp-mcp/whatsapp-bridge/store/.bridge-token)
curl -H "Authorization: Bearer $TOKEN" http://localhost:8080/api/health
# {"connected":true,"status":"ok",...}
```

---

## Document Saving (TSPG WhatsApp)

Every briefing that scans the TSPG group follows the same doc-saving rule:

1. Download media via `whatsapp` MCP `download_media`
2. Look up the original filename from the WhatsApp bridge SQLite DB:
   ```bash
   sqlite3 ~/whatsapp-mcp/whatsapp-bridge/store/messages.db \
     "SELECT filename FROM messages WHERE id='<message_id>'"
   ```
3. Save to Drive as `YYYY-MM-DD_<original_filename>` — date prefix only, original name and extension unchanged
4. Fallback if filename is blank: `YYYY-MM-DD_<media_type>.<ext>` — no sender name
5. **Never convert formats** — `.docx` stays `.docx`, `.pptx` stays `.pptx`

Files are saved per-group to the relevant Drive folder, e.g.:
```
AXINAGRP/XGC-TSPG/whatsapp-docs/          ← TSPG, TGI Tech, Dev, AXINOD UKR
AXINAGRP/Sales/Africa/Angola/whatsapp-docs/
AXINAGRP/Sales/Africa/Uganda/whatsapp-docs/
```

---

## WhatsApp Groups Monitored

### Core 8 Groups (Step 1.5)

| Group | JID | Project | Prefix |
|-------|-----|---------|--------|
| AXINA-TSPG-TEAM | `120363424688758322@g.us` | axina-group-admin | `[TSPG]` |
| TGI Tech | `120363428241001289@g.us` | tgi-corporate / axerp | `[TGI-Tech]` |
| Vista Angola | `120363426342012826@g.us` | angola-admin (ID 8) | `[Angola]` |
| Aimable (Uganda) | *(JID in .people.private.md)* | uganda-admin (ID 7) | `[Uganda]` |
| TGI Geneses | `120363404307998608@g.us` | tgi-corporate / aximedic | `[TGI-Genesys]` |
| Dev Team | `120363407823632328@g.us` | engineering | `[Dev]` |
| AXINOD™ Data UKR | *(JID in .people.private.md)* | axina-group-admin | `[AXINOD]` |
| Erin Davidson | *(JID in .people.private.md)* | axina-group-admin | `[Erin]` |

### NCR Africa Groups (Step 1.6 — 10 groups)

Weekly touchpoint enforcement: if Daniel's last outbound message to any group is >7 days ago, a nudge is drafted for review (never auto-sent).

| Country | JID | Project |
|---------|-----|---------|
| Uganda | `120363404143054230@g.us` | uganda-admin (7) |
| Tanzania | `120363426704399064@g.us` | axina-sales (11) |
| Namibia | `120363425777520890@g.us` | axina-sales (11) |
| Angola | `120363409250806282@g.us` | angola-admin (8) |
| Burkina Faso/Mali | `120363405973801557@g.us` | axina-sales (11) |
| Ethiopia | `120363403317252594@g.us` | axina-sales (11) |
| DRC/Congo | `120363423236647070@g.us` | axina-sales (11) |
| Botswana | `120363419061103953@g.us` | axina-sales (11) |
| Nigeria | *(group not yet created)* | axina-sales (11) |
| South Africa | *(group not yet created)* | axina-sales (11) |

---

## Background Service: OpenProject → WhatsApp Notifier

A separate launchd service (not part of the briefings) runs every 15 minutes and posts OpenProject `axina-group-admin` changes to the TSPG WhatsApp group:

| Event | Message |
|-------|---------|
| New work package | `🆕 New Task` + subject + link |
| Status changed | `📋 OpenProject Update` + old → new + link |
| Assignee changed | `👤 OpenProject Assignment` + who → who + link |

```bash
launchctl list | grep openproject-notifier   # check it's running
tail -f ~/logs/claude-assistant/op-notifier.log   # live log
```

See `../scripts/README.md` and `../mcp-servers/TEAM-INSTALL.md` Step 10 for setup.

---

## Output Files

Daily briefs write to Google Drive (synced, accessible from any device):
```
db@ctorescues.com → My Drive → _daily_brief/
├── 2026-06-09.md          ← morning briefing
├── 2026-06-09-wrapup.md   ← evening wrap-up
├── 2026-06-10.md
└── ...
```

The weekly review reads these files to generate the Sunday rollup.
