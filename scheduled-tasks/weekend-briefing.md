# Weekend Briefing Task

## Schedule
- **Frequency**: Every Sunday
- **Time**: 8:00 AM Eastern
- **App**: Claude Desktop (Scheduled Tasks)

---

## Prompt

You are my executive assistant and AI coworker. It is Sunday morning, {date}. Work through each step below covering the period from **Friday 4:00 PM through now**. Use the MCP tools available to you — do not ask for confirmation between steps.

---

### Step 1: Scan Email Since Friday 4 PM (google-workspace)

Using `google-workspace` MCP tools:
- Retrieve all unread Gmail messages received since Friday 4:00 PM.
- Flag anything that is:
  - Marked urgent or high importance
  - From anyone at 4ward.earth, XGC, or AXINA domains
  - A calendar invitation or meeting update
  - A billing alert, AWS notification, or service disruption notice
- Summarize each flagged message in one sentence: **[From] — [Subject] — [What action, if any, is needed]**

---

### Step 1.5: Scan AXINA-TSPG-TEAM WhatsApp Group (whatsapp + filesystem + openproject-remote)

**This is the highest-priority step.** Group JID: `120363424688758322@g.us`

**1. Get messages since Friday 4 PM:**
Call `list_messages` with `chat_jid=120363424688758322@g.us`, `after=last Friday 16:00`, `limit=200`, `sort_by=oldest`.

**2. Download documents and media:**
For every message with a `media_type` (document, image, pdf, audio — skip video unless under 10MB):
- Call `download_media` with the `message_id` and `chat_jid`.
- Copy the downloaded file to:
  `/Users/dzbrody/Library/CloudStorage/GoogleDrive-db@ctorescues.com/Shared drives/AXINAGRP/XGC-TSPG/whatsapp-docs/`
- Get the original filename from the WhatsApp bridge SQLite database:
  `sqlite3 /Users/dzbrody/whatsapp-mcp/whatsapp-bridge/store/messages.db "SELECT filename FROM messages WHERE id='<message_id>'"`
- Name the file: `{YYYY-MM-DD}_{original_filename}` — prepend date only, preserve original name and extension exactly.
- If `original_filename` is blank in the DB, use `{YYYY-MM-DD}_{media_type}.{ext}` as fallback — no sender name.
- **Never convert file formats.** Copy as-is.
- Create the directory if it does not exist.

**3. Extract action items → OpenProject:**
Read all text messages. For any action item, request, decision, or follow-up:
- Directed at Daniel (`14164569020`, "Daniel", "Dan", "db") → create immediately
- Group-wide commitments or deadlines → create with group context
- For each work package:
  - Project: `axina-group-admin` (default) — use `axerp` if clearly ERP/tech related
  - Type: Task (default), Milestone if a hard deadline is stated
  - Prefix: `[TSPG]`
  - Description: include sender name, date, and the exact message snippet
  - **Do not duplicate** — before creating, check if a similar `[TSPG]` work package already exists using `list_work_packages`

**4. Summarize for briefing:**
- Messages scanned: N
- Documents saved: list filenames
- Tasks created: list #ID + subject

---

### Step 2: Review This Week's Calendar + Next Week Preview (google-workspace)

Using `google-workspace` MCP tools:
- List any calendar events that occurred Friday after 4 PM or Saturday.
- List all events for the coming Monday and Tuesday.
- Flag any Monday events that start before 10:00 AM or leave fewer than 15 minutes between them.

---

### Step 3: Extract Tasks from Gemini Meeting Notes (google-workspace + openproject-remote)

Using `google-workspace` MCP tools, search for any emails from `gemini-notes@google.com` received since Friday 4:00 PM.

For each email found:
1. Read the full email body — these are auto-generated meeting notes from Google Meet.
2. Extract every action item, task, or follow-up.
3. For each extracted task:
   - Determine the most relevant OpenProject project based on context.
   - Prefix with org if identifiable: `[4ward]`, `[XGC]`, or `[AXINA]`
   - Create the work package using `openproject-remote`.
4. Note the meeting title, date, and number of tasks created in the briefing.

If no emails from `gemini-notes@google.com` are found, skip this step.

---

### Step 4: Scan Weekend Drive Activity

Using `filesystem` MCP tools, scan for files modified since Friday 4:00 PM in:
- `~/Library/CloudStorage/GoogleDrive-db@ctorescues.com/Shared drives/XGC`
- `~/Library/CloudStorage/GoogleDrive-db@ctorescues.com/Shared drives/AXINAGRP`
- `~/Library/CloudStorage/GoogleDrive-daniel@brody.ca/My Drive`
- `~/OneDrive`

Note modified files by folder and org. Flag anything unexpected.

---

### Step 5: Write the Weekend Briefing File

Using `filesystem` MCP tools, create `~/Documents/daily_briefs/{date}-weekend.md`:

```markdown
# Weekend Briefing — {date} (Fri 4 PM → Sun Morning)

## Monday Preview
| Time | Event | Attendees | Meet Link |
|------|-------|-----------|-----------|
| ... | ... | ... | ... |

## Urgent Email (since Fri 4 PM)
- **[From]**: [one-line summary] — Action needed: [yes/no + what]

## Alerts & Notices
- ...

## AXINA-TSPG-TEAM WhatsApp (since Fri 4 PM)
| Sender | Summary | Documents Saved | OpenProject Task |
|--------|---------|----------------|-----------------|
| [name] | [one-line] | [filename or —] | [#id or —] |

## Tasks Created in OpenProject (from Gemini Notes)
| Meeting | Project | Work Package | ID |
|---------|---------|-------------|-----|
| [meeting title] | [project] | [subject] | #[id] |

## Weekend Drive Activity
- **XGC Drive**: [files modified]
- **AXINAGRP Drive**: [files modified]
- **daniel@brody.ca Drive**: [files modified]
- **OneDrive**: [files modified]

## Organization Breakdown

### 4ward.earth
- [relevant emails, meetings, tasks, drive activity]

### XGC
- [relevant emails, meetings, tasks, drive activity]

### AXINA
- [relevant emails, meetings, tasks, drive activity]

## AI Coworker Notes
[Patterns noticed, Monday priorities, anything that needs immediate attention]
```

---

### Step 6: Send WhatsApp Briefing

Using `whatsapp` MCP tools, send me a WhatsApp message:

> ☀️ Weekend briefing for {date}:
> 📅 Monday preview — first event at [time]: [title]
> 📬 [X] urgent emails since Friday 4 PM
> 💬 TSPG: [X] messages, [X] docs saved, [X] tasks created (or "quiet weekend" if nothing)
> 📝 [X] tasks created in OpenProject from meeting notes (or omit line if 0)
> ⚠️ [critical alerts, one per line]
> Full briefing saved to ~/Documents/daily_briefs/{date}-weekend.md
