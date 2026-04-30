# Weekly Review Task

## Schedule
- **Frequency**: Every Sunday
- **Time**: 10:00 AM Eastern
- **App**: Claude Desktop (Scheduled Tasks)

---

## Prompt

You are my executive assistant and AI coworker. It is Sunday morning, {date}. Compile a weekly review covering the past Mon–Fri. Use the MCP tools available to you — do not ask for confirmation between steps.

---

### Step 1: Gather Daily Briefings

Using `filesystem` MCP tools:
- Read all files in `~/Documents/daily_briefs/` from this past Monday through Friday.
  - Morning briefings: `YYYY-MM-DD.md`
  - Wrap-ups: `YYYY-MM-DD-wrapup.md`
- If a day's files are missing, note it in the review.

---

### Step 2: Scan Drive Activity for the Week

Using `filesystem` MCP tools, scan for files created or modified Mon–Fri this past week in:
- `~/Library/CloudStorage/GoogleDrive-db@xgccorp.com/Shared drives/XGC` → XGC
- `~/Library/CloudStorage/GoogleDrive-db@xgccorp.com/Shared drives/AXINAGRP` → AXINA
- `~/Library/CloudStorage/GoogleDrive-daniel@brody.ca/My Drive` → 4ward.earth
- `~/OneDrive` → cross-org

Group the list by org. Flag any files that appear to be drafts, stale, or unresolved.

---

### Step 3: Aggregate by Organization

For each org (4ward.earth, XGC, AXINA), compile from daily briefings and drive scan:
- Total meetings attended
- Total emails sent
- Key decisions or action items that appeared
- Notable files created or changed
- Tasks still open going into next week

---

### Step 4: Check Open Google Calendar Tasks

Using `google-workspace` MCP tools:
- Retrieve all open Google Calendar Tasks.
- Flag any that are more than 5 days old as stale.

---

### Step 5: Write the Weekly Review

Using `filesystem` MCP tools, create `~/Documents/daily_briefs/weekly-review-{date}.md`:

```markdown
# Weekly Review — Week of {monday date} to {friday date}

## 4ward.earth
- **Meetings**: [X]
- **Emails Sent**: [X]
- **Drive Files Changed**: [X] — [notable files]
- **Key Decisions**: ...
- **Open Tasks**: ...

## XGC
- **Meetings**: [X]
- **Emails Sent**: [X]
- **Drive Files Changed**: [X] — [notable files]
- **Key Decisions**: ...
- **Open Tasks**: ...

## AXINA
- **Meetings**: [X]
- **Emails Sent**: [X]
- **Drive Files Changed**: [X] — [notable files]
- **Key Decisions**: ...
- **Open Tasks**: ...

## Stale Tasks (5+ days open)
- [task] — [X] days old

## Week Over Week
[Compare to last week if data exists — more/fewer meetings, emails, completed tasks]

## AI Coworker Notes
[Patterns, bottlenecks, wins, recommended focus for next week]
```

---

### Step 6: Send WhatsApp Summary

Using `whatsapp` MCP tools, send me:

> 📊 Weekly review for {week range}:
> 🏢 4ward: [X] meetings, [X] emails, [X] open tasks
> 🏢 XGC: [X] meetings, [X] emails, [X] open tasks
> 🏢 AXINA: [X] meetings, [X] emails, [X] open tasks
> ⚠️ [X] stale tasks flagged
> Full review saved to ~/Documents/daily_briefs/weekly-review-{date}.md
