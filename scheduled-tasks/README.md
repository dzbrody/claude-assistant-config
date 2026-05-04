# Scheduled Tasks

Prompts for the four automated briefings. These are run via the **🤖 Claude Assistant menu bar app** — see `../desktop/README.md` for installation.

---

## Active Tasks

| File | When | What It Does |
|------|------|-------------|
| `morning-briefing.md` | Weekdays, ~7:00 AM | Scans TSPG WhatsApp (saves docs to Drive with original filenames, creates OpenProject tasks), scans Gmail, extracts Gemini meeting note tasks, reviews calendar, writes `~/Documents/daily_briefs/YYYY-MM-DD.md`, sends WhatsApp summary |
| `evening-wrap-up.md` | Weekdays, ~6:00 PM | Scans TSPG for daytime activity (new docs + tasks), reviews sent email, scans modified Drive files, checks open tasks, previews tomorrow, writes wrapup file, sends WhatsApp summary |
| `weekend-briefing.md` | Sundays, ~8:00 AM | Covers Fri 4 PM → Sun morning: full TSPG catch-up, urgent email scan, Gemini notes, Drive activity, Monday preview, sends WhatsApp summary |
| `weekly-review.md` | Sundays, ~10:00 AM | Reads all daily brief files, aggregates by org (4ward / XGC / AXINA), flags stale OpenProject tasks, sends WhatsApp summary |

All briefing files are written to `~/Documents/daily_briefs/`.

---

## Required MCP Servers

All four tasks require these MCP servers to be configured in `.claude/settings.local.json`:

| Server | Used for |
|--------|---------|
| `google-workspace` | Gmail, Google Calendar, Google Tasks |
| `whatsapp` | TSPG group messages, media download, send summaries |
| `filesystem` | Save docs to Google Drive, write briefing files |
| `openproject-remote` | Create and list work packages |

The WhatsApp bridge must be running:
```bash
curl http://localhost:8080/api/health
# {"connected":true,...}
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

Files are saved to:
```
~/Library/CloudStorage/GoogleDrive-db@xgccorp.com/Shared drives/AXINAGRP/XGC-TSPG/whatsapp-docs/
```

---

## AXINA-TSPG-TEAM Group

| Setting | Value |
|---------|-------|
| Chat JID | `120363424688758322@g.us` |
| Priority | Highest — Step 1.5 runs before email in morning brief |
| Docs saved to | `AXINAGRP/XGC-TSPG/whatsapp-docs/` |
| Tasks created in | OpenProject `axina-group-admin`, prefixed `[TSPG]` |
| Task dedup | Checks existing `[TSPG]` work packages before creating |

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

```
~/Documents/daily_briefs/
├── 2026-05-04.md          ← morning briefing
├── 2026-05-04-wrapup.md   ← evening wrap-up
├── 2026-05-05.md
└── ...
```

The weekly review reads these files to generate the Sunday rollup.
