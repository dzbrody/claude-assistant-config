# Release Notes — PMO Automation Hub v2.0
**Date:** June 11, 2026
**Branch:** main
**Commits:** b6b11de → d205b5f (6 commits today)

---

## 🚀 What Shipped Today

This release delivers three things: a hardened, production-ready backend (8 bug/security fixes), a remote EC2 Whisper transcription pipeline, and a full CLI command matrix for automated project management.

---

## ✨ New Features

### `/transcribe` — Upgraded (Google Drive / Meet support)
- Now detects whether the input is an AWS S3 key or a Google Drive / Meet URL
- Drive path: extracts file ID → fetches metadata via Workspace MCP → downloads and stages to `s3://axina-openproject-files/meet-recordings/` → triggers EC2 Whisper pipeline
- MacBook bandwidth untouched — all media transfer flows through the MCP layer
- Post-transcription: optionally creates OpenProject tasks from action items using the Project Routing Guide
- *Commit: `3134707`*

### `/ingest-meeting-notes` — New Command
- Fetches `gemini-notes@google.com` emails from the last 48 hours via Gmail MCP
- Business context filter: strips filler, maps names to OP user IDs (Sean McNeill → external, follow-up assigned to Dan), routes each action item to the correct project using the Axina Project Routing Guide
- Deduplicates against open tasks before creating any work package
- Tested live today: ingested 2 emails, created 9 work packages across `axina-sales`, `kazakhstan-admin`, `tgi-corporate`, and `m-and-a`
- *Commit: `3134707`*

### `/pmo-dedup` — New Command
- Scans open work packages across all 10 active projects in parallel
- Detects duplicates by exact title match or 4+ shared words / shared key noun phrase
- Merges unique description content from the newer task into the master; closes duplicate with a `"Closing as duplicate of #[id]"` comment
- Presents a confirmation table before any writes — nothing closes headlessly
- *Commit: `d205b5f`*

### `/pmo-track-time` — New Command
- Matches today's Google Calendar events to OP work packages by `#ID` in title/description, "PMO Focus Block" pattern, or keyword search
- Computes exact durations in decimal hours; POSTs time entries under Dan Brody (user ID 5) via OP REST
- Presents match table with match confidence (exact / keyword / unmatched) before posting
- *Commit: `d205b5f`*

### `/pmo-sweep-completed` — New Command
- Flags open tasks where `percentageDone = 100` or all child work packages are closed
- Excludes: Milestones, `[NCR-]` prefixed tasks (require field confirmation), tasks with future due dates and no progress indicator
- Closes confirmed tasks with an audit comment; prints a cleanup ledger
- *Commit: `d205b5f`*

### `/pmo-schedule-focus` — New Command
- Pulls top 5 overdue/high-priority OP tasks assigned to Dan
- Scans the next 48 hours of calendar for free blocks (min 45 min, 8 AM–7 PM ET, 15 min buffer around existing meetings)
- Creates `"PMO Focus Block: [Task Name] (OP#id)"` calendar events with OP links in description
- Confirm before inserting; reports tasks with no available slot
- *Commit: `d205b5f`*

### `/pmo-clean-backlog` — New Command
- Finds open tasks missing assignee, start date, or due date
- Smart defaults by subject prefix: `[Angola]` → Dan + version 29 (Active Deployment); `[Uganda]` → Dan + version 20 (MOU); `[TSPG]`/`[Dev]`/`[Gemini]` → Dan as triage owner; no prefix → flagged for manual review (not auto-assigned)
- Sets missing start dates to today; missing due dates to +14 days (triage placeholder, noted in description); inherits version end date when available
- Confirm before writing
- *Commit: `d205b5f`*

### EC2 Remote MCP Server — Whisper Pipeline
- Dockerfile: switched Python 3.13 → 3.12 for stable `ctranslate2` wheels; added system `ffmpeg`; baked in `faster-whisper 1.0.3`; set `HF_HOME` to container-local cache with correct ownership
- `transcribe_s3_audio` tool: downloads audio from S3, transcribes on CPU via `int8` quantization (fast, no GPU needed), returns timestamped transcript; `try/finally` guarantees temp file cleanup; bucket allowlist enforced
- Container runs under unprivileged `mcp` user; write permissions scoped to model cache only
- *Commit: `8645187`*

### Morning Briefing — Interactive NCR Nudge Dispatch (Step 7)
- After writing the daily brief file, for each NCR group flagged `⚠️ NUDGE DUE`, the briefing now pauses, prints the drafted message, and asks `Send nudge to NCR - [Country] group? [y/N]`
- Sends via WhatsApp MCP on `y`; skips on anything else; prints a summary count at the end
- *Commit: `8645187`*

### `/whatsapp-cmd` — WhatsApp Command Hub Script
- `scripts/whatsapp-cmd-hub.py`: polls Dan's direct WhatsApp chat for `!status`, `!deadlines`, `!brief`, `!ncr`, `!help` triggers
- Responds via WhatsApp bridge with Bearer auth; state-tracked via `last_processed` timestamp; safe for 15-min cron
- Project shorthand aliases: `uganda`, `angola`, `tgi`, `axinod`, `sales`
- *Commit: `ad5de0b`*

---

## 🔧 Bug Fixes & Security

All 8 findings from the prior code review resolved in commit `b6b11de`:

| Area | Fix |
|---|---|
| `ssm-mcp-tunnel.sh` | Port `39127` → `39128` to match server binding |
| `openproject-whatsapp-notifier.py` | Inject Bearer token in WhatsApp bridge requests (v0.3.0+ auth requirement) |
| `decommission-nextcloud.sh` | Replace single-page S3 list call with pagination loop — handles buckets with >1,000 object versions |
| `server.py` | Tighten `/messages/` auth bypass: require `session_id` query param to prevent crafted-path bypass |
| `run-scheduled-task.sh` | Pass `PEOPLE_FILE` via `os.environ` instead of shell string interpolation into Python literal (script injection fix) |
| `run-scheduled-task.sh` | Add `trap EXIT` block — guarantees temp cleartext prompt file is wiped on any exit path |
| `server.py` | `get_s3_object` uses `Range: bytes=0-10239` header to prevent OOM on large S3 objects |
| `openproject-whatsapp-notifier.py` | `save_state` now runs only after all notifications succeed; failures exit 1 to preserve the retry window |

---

## 📋 Command Reference (Full Matrix as of v2.0)

| Command | What it does |
|---|---|
| `/brief-morning` | Scan email, WhatsApp groups, calendar, Gemini notes, create OP tasks, interactive NCR nudge dispatch |
| `/brief-evening` | Evening wrap-up — sent email, calendar, TSPG WhatsApp, Zoom notes, task status |
| `/review-weekly` | Aggregate Mon–Fri briefs, team velocity, stalled items, NCR touchpoints |
| `/brief-weekend` | Strategic analysis over technical specs and milestones |
| `/transcribe` | Transcribe audio/video from S3 or Google Drive / Meet link via EC2 Whisper |
| `/ingest-meeting-notes` | Fetch `gemini-notes@google.com`, apply business context filter, create OP tasks |
| `/pmo-dedup` | Detect and collapse duplicate work packages (confirm before closing) |
| `/pmo-track-time` | Match calendar events to OP tasks, log time entries (confirm before posting) |
| `/pmo-sweep-completed` | Auto-close 100%-done tasks (confirm before closing) |
| `/pmo-schedule-focus` | Book "PMO Focus Block" calendar slots for top priority tasks (confirm before inserting) |
| `/pmo-clean-backlog` | Triage tasks missing assignee/dates with smart defaults (confirm before writing) |
| `/whatsapp-cmd` | WhatsApp `!command` hub polling loop |
| `/tunnel-ssm` | Open SSM port-forward tunnel to EC2 MCP server on port 39128 |
| `/health-check` | Local health check — MCP servers, Drive mounts, task files, logs |
| `/decommission` | Decommission Nextcloud S3 bucket (paginated delete, typed confirmation) |

**Active integrations:** WhatsApp MCP · OpenProject MCP (remote) · Google Workspace MCP · AWS S3 · EC2 Whisper (faster-whisper int8, Python 3.12)
