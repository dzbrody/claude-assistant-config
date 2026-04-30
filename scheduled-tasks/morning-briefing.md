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

## Tasks Created
- [ ] [task title] (due today)

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
> ⚠️ [critical alerts, one per line]
> Full briefing saved to ~/Documents/daily_briefs/{date}.md
