# Evening Wrap-Up Task

## Schedule
- **Frequency**: Every weekday (Mon–Fri)
- **Time**: 6:00 PM Eastern
- **App**: Claude Desktop (Scheduled Tasks)

---

## Prompt

You are my executive assistant and AI coworker. It is the end of the workday on {date}. Work through each step below in order and compile a wrap-up. Use the MCP tools available to you — do not ask for confirmation between steps.

---

### Step 1: Review Today's Sent Email

Using `google-workspace` MCP tools:
- Retrieve all emails I sent today.
- For each: summarize in one line — recipient, subject, and whether it is likely to need follow-up.

---

### Step 2: Review Calendar

Using `google-workspace` MCP tools:
- List today's calendar events and note whether each had a Google Meet link.
- Check tomorrow's calendar. List the first 3 events with time and title.

---

### Step 3: Files Modified Today

Using `filesystem` MCP tools, scan the following locations for files created or modified today:
- `~/Documents` — personal
- `~/Downloads` and `~/Desktop`
- `~/Library/CloudStorage/GoogleDrive-db@xgccorp.com/Shared drives/XGC`
- `~/Library/CloudStorage/GoogleDrive-db@xgccorp.com/Shared drives/AXINAGRP`
- `~/Library/CloudStorage/GoogleDrive-daniel@brody.ca/My Drive`
- `~/OneDrive`

Group results by location and org. Flag any that look incomplete: tmp files, untitled documents, empty files.

---

### Step 3.5: Scan AXINA-TSPG-TEAM WhatsApp Group (whatsapp + filesystem + openproject-remote)

**Group JID:** `120363424688758322@g.us`

**1. Get today's messages:**
Call `list_messages` with `chat_jid=120363424688758322@g.us`, `after=today 07:00`, `limit=100`, `sort_by=oldest`.

**2. Download any new documents or media:**
For every message with a `media_type` received after 7:00 AM today:
- Call `download_media` and copy to:
  `/Users/dzbrody/Library/CloudStorage/GoogleDrive-db@xgccorp.com/Shared drives/AXINAGRP/XGC-TSPG/whatsapp-docs/`
- Get the original filename from the WhatsApp bridge SQLite database:
  `sqlite3 /Users/dzbrody/whatsapp-mcp/whatsapp-bridge/store/messages.db "SELECT filename FROM messages WHERE id='<message_id>'"`
- Name the file: `{YYYY-MM-DD}_{original_filename}` — prepend date only, preserve original name and extension exactly.
- If `original_filename` is blank, use `{YYYY-MM-DD}_{media_type}.{ext}` as fallback — no sender name.
- **Never convert file formats.** Copy as-is.

**3. Extract new action items → OpenProject:**
For any action items or follow-ups not yet captured this morning:
- Check existing `[TSPG]` work packages with `list_work_packages` before creating to avoid duplicates.
- Create new ones with project `axina-group-admin`, prefix `[TSPG]`, include message snippet in description.

**4. Summarize for wrap-up:**
- New messages since morning: N
- New documents saved: list filenames (or "none")
- New tasks created: list #ID + subject (or "none")

---

### Step 4: Google Calendar Tasks — Status Check

Using `google-workspace` MCP tools:
- Retrieve all Google Calendar Tasks due today.
- Note which are completed and which are still open.
- For each open task, suggest: carry to tomorrow, defer, or escalate.

---

### Step 5: Write the Wrap-Up File

Using `filesystem` MCP tools, create `~/Documents/daily_briefs/{date}-wrapup.md`:

```markdown
# Wrap-Up — {date}

## Email Sent Today
| To | Subject | Follow-Up Needed? |
|----|---------|-------------------|
| ... | ... | Yes / No |

## Meetings Today
| Event | Notes |
|-------|-------|
| ... | ... |

## AXINA-TSPG-TEAM WhatsApp (today)
| Sender | Summary | Doc Saved | Task Created |
|--------|---------|-----------|-------------|
| ... | ... | ... | ... |

## Files Modified Today
- **Personal (Documents/Downloads/Desktop)**: ...
- **XGC Drive (My Drive)**: ...
- **XGC Drive (Shared/XGC)**: ...
- **XGC Drive (Shared/AXINAGRP)**: ...
- **daniel@brody.ca Drive**: ...
- **OneDrive**: ...

## Task Status
- [x] Completed: ...
- [ ] Carried to tomorrow: ...
- [ ] Deferred: ...

## Tomorrow's First 3
1. [time] — [event title]
2. [time] — [event title]
3. [time] — [event title]

## AI Coworker Notes
[What got done, what got stuck, what to prioritize tomorrow, anything unusual]
```

---

### Step 6: Send WhatsApp Summary

Using `whatsapp` MCP tools, send me:

> 🌙 Wrap-up for {date}:
> ✉️ [X] emails sent
> 📅 [X] meetings completed
> 💬 TSPG: [X] msgs, [X] docs saved, [X] tasks created (or "quiet today")
> 📂 [X] files modified
> ⚠️ [X] tasks carried to tomorrow
> Full wrap-up saved to ~/Documents/daily_briefs/{date}-wrapup.md
