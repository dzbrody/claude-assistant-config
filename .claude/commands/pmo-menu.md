# PMO Master Command Directory

Print the following table to the terminal exactly as shown. Do not execute any other tools — this is a read-only reference display.

---

## PMO Master Command Directory

| Command | What it does |
|---|---|
| `/pmo-menu` | Show this command reference |
| `/brief-morning` | Run morning briefing — scan email, WhatsApp groups, calendar, Gemini notes, create OP tasks, interactive NCR nudge dispatch |
| `/brief-evening` | Run evening wrap-up — sent email, calendar, TSPG WhatsApp, Zoom notes, task status, WhatsApp summary |
| `/review-weekly` | Run weekly review — aggregate Mon–Fri briefs, team velocity, stalled items, NCR touchpoints |
| `/brief-weekend` | Run weekend briefing — strategic analysis over technical specs and milestones |
| `/transcribe` | Transcribe audio/video from S3 **or Google Drive / Meet link** using Whisper on EC2 |
| `/ingest-meeting-notes` | Fetch latest `gemini-notes@google.com` emails, apply business context filter, create OpenProject tasks |
| `/pmo-dedup` | Scan open tasks across all projects, detect duplicate titles/deliverables, merge unique details into master, close duplicates — confirm before applying |
| `/pmo-track-time` | Match today's calendar events to OP work packages by ID or keyword, compute durations, log time entries under Daniel's profile — confirm before posting |
| `/pmo-sweep-completed` | Audit open tasks for 100% progress or all-children-closed; present closure candidates and auto-close on confirmation |
| `/pmo-schedule-focus` | Pull top 5 overdue/high-priority OP tasks, find free calendar slots in next 48h, create "PMO Focus Block" events — confirm before inserting |
| `/pmo-clean-backlog` | Find open tasks missing assignee, start date, or due date; apply smart defaults by project prefix; confirm before writing |
| `/whatsapp-cmd` | Start WhatsApp command hub polling loop — responds to !status, !deadlines, !brief triggers |
| `/tunnel-ssm` | Open SSM port-forward tunnel to EC2 MCP server on port 39128 |
| `/health-check` | Run local health check — MCP servers, Drive mounts, task files, logs directory |
| `/decommission` | Decommission Nextcloud S3 bucket (paginated delete, requires typed confirmation) |

**Active integrations:** WhatsApp MCP · OpenProject MCP (remote) · Google Workspace MCP · AWS S3 · EC2 Whisper

---

After printing the table, ask: "Which command would you like to run?"
