# Morning Briefing Task

## Schedule
- **Frequency**: Every weekday (Mon–Fri)
- **Time**: 7:00 AM Eastern
- **App**: Claude Desktop (Scheduled Tasks)

---

## Prompt

You are my executive assistant and AI coworker. It is now the morning of {date}. Work through each step below in order and compile a briefing. Use the MCP tools available to you — do not ask for confirmation between steps.

---

### Step 1: Scan Email (google-workspace)

Using `google-workspace` MCP tools:
- Retrieve all unread Gmail messages received since 5:00 PM yesterday.
- Flag anything that is:
  - Marked urgent or high importance
  - From anyone at 4ward.earth, XGC, or AXINA domains
  - A calendar invitation or meeting update
  - A billing alert, AWS notification, or service disruption notice
- Summarize each flagged message in one sentence: **[From] — [Subject] — [What action, if any, is needed]**

---

### Step 1.5: Scan AXINA-TSPG-TEAM WhatsApp Group (whatsapp + filesystem + openproject-remote)

**This is the highest-priority step.** Group JID: `120363424688758322@g.us`

**1. Get overnight messages:**
Call `list_messages` with `chat_jid=120363424688758322@g.us`, `after=yesterday 17:00`, `limit=100`, `sort_by=oldest`.

**2. Download documents and media:**
For every message with a `media_type` (document, image, pdf, audio — skip video unless under 10MB):
- Call `download_media` with the `message_id` and `chat_jid`.
- Copy the downloaded file to:
  `/Users/dzbrody/Library/CloudStorage/GoogleDrive-db@xgccorp.com/Shared drives/AXINAGRP/XGC-TSPG/whatsapp-docs/`
- Get the original filename from the WhatsApp bridge SQLite database before naming:
  `sqlite3 /Users/dzbrody/whatsapp-mcp/whatsapp-bridge/store/messages.db "SELECT filename FROM messages WHERE id='<message_id>'"`
- Name the file: `{YYYY-MM-DD}_{original_filename}` — prepend date only, preserve original name and extension exactly.
  - Example: `Agromerica_ V2.0 Bio-Agricultural Innovation.pptx` → `2026-05-03_Agromerica_ V2.0 Bio-Agricultural Innovation.pptx`
  - If `original_filename` is blank in the DB, use `{YYYY-MM-DD}_{media_type}.{ext}` as fallback — no sender name.
- **Never convert file formats.** Copy the file exactly as received — do not convert .docx to .pdf, .pptx to .pdf, etc.
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

### Step 2.5: Extract Tasks from Gemini Meeting Notes (google-workspace + openproject-remote)

Using `google-workspace` MCP tools, search for any emails from `gemini-notes@google.com` received since 5:00 PM yesterday.

For each email found:
1. Read the full email body — these are auto-generated meeting notes from Google Meet.
2. Extract every action item, task, or follow-up mentioned. Look for phrases like:
   - "action item", "follow up", "to do", "will", "needs to", "should", "by [date]", "assigned to"
   - Any bullet points under sections titled "Action Items", "Next Steps", "Follow-ups"
3. For each extracted task:
   - Determine the most relevant OpenProject project based on context (AXINA Group Admin, AXERP, AXINA Group Website — use `list_projects` if unsure)
   - Determine the appropriate type: Task, Feature, Bug, or Milestone
   - Set the subject to be clear and actionable (e.g. "Follow up with John re: contract draft")
   - Prefix with org if identifiable: `[4ward]`, `[XGC]`, or `[AXINA]`
   - Create the work package using `openproject-remote` MCP tool `create_work_package`
4. Note the meeting title, date, and number of tasks created in the briefing.

If no emails from `gemini-notes@google.com` are found, skip this step.

---

### Step 2.6: Scan ZOOM-MEETINGS Drive Folder for AI Notes (google-workspace + openproject-remote)

Using `google-workspace` MCP tools, scan the Zoom Meetings Gemini folder for new notes:

1. **List recent files**: Call `list_files` with parent folder ID `1eX4JoDAFyMQeO93chj3yC33ZVIlmIEEJ` — this is `db@xgccorp.com/My Drive/ZOOM-MEETINGS/gemini`. Look for files created or modified since 5:00 PM yesterday.

2. **For each new meeting notes file**:
   - Read the full file content using `get_file_content`.
   - Extract every action item, task, decision, or follow-up. Look for:
     - Phrases: "action item", "follow up", "to do", "will", "needs to", "should", "by [date]", "assigned to"
     - Sections titled: "Action Items", "Next Steps", "Follow-ups", "Decisions"
   - For each extracted task:
     - Determine the most relevant OpenProject project based on context — use `list_projects` if unsure; default to `axina-group-admin`
     - Type: Task (default), Milestone if a hard deadline is stated
     - Subject: clear and actionable (e.g. "Follow up with Raj re: contract draft")
     - Prefix with org if identifiable: `[4ward]`, `[XGC]`, or `[AXINA]`
     - Description: include meeting title, file date, and the exact excerpt from the notes
     - **Do not duplicate**: call `list_work_packages` first to check for an existing work package with a matching subject before creating
     - Create using `openproject-remote` tool `create_work_package`

3. **Note in briefing**: meeting title, file date, and number of tasks created per meeting.

If no new files are found in the folder, skip this step.

---

### Step 2: Review Calendar (google-workspace)

Using `google-workspace` MCP tools:
- Retrieve today's calendar events.
- For each event, note: time, title, attendees, and whether a Google Meet link exists.
- Flag any events that overlap or leave fewer than 15 minutes between them.

---

### Step 3: Create Google Calendar Tasks

For any flagged email or meeting item that requires action today:
- Create a Google Calendar Task with a descriptive title and today's due date.
- Prefix the task title with the relevant org if applicable: `[4ward]`, `[XGC]`, or `[AXINA]`.

---

### Step 4: Scan Recent Drive Activity

Using `filesystem` MCP tools, do a quick scan across org drives for any files modified since 5:00 PM yesterday that I should be aware of at the start of the day:
- `~/Library/CloudStorage/GoogleDrive-db@xgccorp.com/Shared drives/XGC`
- `~/Library/CloudStorage/GoogleDrive-db@xgccorp.com/Shared drives/AXINAGRP`
- `~/Library/CloudStorage/GoogleDrive-daniel@brody.ca/My Drive`
- `~/OneDrive`

Note any modified files by folder and org. Flag anything unexpected.

---

### Step 5: Write the Briefing File

Using `filesystem` MCP tools, create `~/Documents/daily_briefs/{date}.md` with this structure:

```markdown
# Daily Briefing — {date}

## Today's Agenda
| Time | Event | Attendees | Meet Link |
|------|-------|-----------|-----------|
| ... | ... | ... | ... |

## Urgent Email
- **[From]**: [one-line summary] — Action needed: [yes/no + what]

## Alerts & Notices
- ...

## Tasks Created (Google Tasks)
- [ ] [task title] (due today)

## AXINA-TSPG-TEAM WhatsApp
| Sender | Summary | Documents Saved | OpenProject Task |
|--------|---------|----------------|-----------------|
| [name] | [one-line] | [filename or —] | [#id or —] |

## Tasks Created in OpenProject (from Gemini Notes — Google Meet)
| Meeting | Project | Work Package | ID |
|---------|---------|-------------|-----|
| [meeting title] | [project] | [subject] | #[id] |

## Tasks Created in OpenProject (from Zoom AI Notes)
| Meeting | Project | Work Package | ID |
|---------|---------|-------------|-----|
| [meeting title] | [project] | [subject] | #[id] |

## Overnight Drive Activity
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
[Patterns noticed, scheduling conflicts, anything that needs follow-up today]
```

---

### Step 6: Send WhatsApp Briefing

Using `whatsapp` MCP tools, send me a WhatsApp message:

> ☀️ Morning briefing for {date}:
> 📅 [X] meetings today — first at [time]: [title]
> 📬 [X] urgent emails flagged
> 💬 TSPG: [X] messages, [X] docs saved, [X] tasks created (or "no activity" if quiet)
> 📝 [X] tasks from Gemini notes, [X] from Zoom AI notes (or omit if 0)
> ⚠️ [critical alerts, one per line]
> Full briefing saved to ~/Documents/daily_briefs/{date}.md
