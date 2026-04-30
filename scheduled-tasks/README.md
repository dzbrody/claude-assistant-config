# Scheduled Task Prompts

Prompts for Claude Desktop's Scheduled Tasks feature. Each file is a self-contained prompt that Claude runs automatically on a set schedule.

## Active Tasks

| File | Schedule | Summary |
|------|----------|---------|
| `morning-briefing.md` | Weekdays, 7:00 AM ET | Scans Gmail since 5 PM yesterday, reviews today's calendar, creates Google Tasks for action items, writes a briefing file, sends a WhatsApp summary |
| `evening-wrap-up.md` | Weekdays, 6:00 PM ET | Reviews sent mail, checks task status, scans modified files, previews tomorrow's calendar, sends a WhatsApp wrap-up |
| `weekly-review.md` | Sundays, 10:00 AM ET | Reads all daily briefings from the past week, aggregates by org (4ward.earth / XGC / AXINA), flags stale tasks, sends a WhatsApp summary |

All output files are written to `~/Documents/daily_briefs/`.

## How to Load a Prompt

1. Open **Claude Desktop**
2. Click **Schedule** in the sidebar
3. Click **+ New task**
4. Paste the prompt text from the relevant `.md` file (the contents of the `## Prompt` section)
5. Set the frequency and time
6. Click **Run once** to test and approve MCP permissions before the first scheduled run

## MCP Tools Used

These tasks rely on the following MCP servers being installed and authenticated:

| Tool | Used By |
|------|---------|
| `google-workspace` | All three tasks (Gmail, Calendar, Tasks) |
| `whatsapp` | All three tasks (summary messages) |
| `filesystem` | All three tasks (write briefing files) |

Run `claude mcp list` to confirm all servers are registered.
