# Changelog

All notable changes to this project are documented here.

---

## [Unreleased] — 2026-06-18

### Changed — `scripts/run-scheduled-task.sh`

- **Single claude invocation**: Email summary instruction is now appended to the task prompt, eliminating the second `claude` spawn that ran post-task. Reduces MCP server init overhead by ~50% per run.
- **AWS credential caching**: `aws sts get-caller-identity` result is cached for 30 minutes via `~/.aws/.cred-cache-xgc-main`. Subsequent runs within the window skip the STS call entirely.
- **WhatsApp health check timeout**: `curl` now passes `-m 3` to cap the bridge health check at 3 seconds, preventing a hung bridge from blocking the entire run indefinitely.

---

## [2.0.0] — 2026-06-11

Full release notes: [RELEASE-NOTES-v2.0.md](RELEASE-NOTES-v2.0.md)

### Added
- OpenProject remote MCP server (49 tools, FastMCP 3.4.2, SSE transport) deployed on EC2
- `openproject-whatsapp-notifier.py` launchd service — posts new tasks, status changes, and assignments to TSPG WhatsApp group every 15 minutes
- `/pmo-*` slash command suite: dedup, track-time, sweep-completed, schedule-focus, clean-backlog
- `/transcribe` — audio/video transcription via EC2 Whisper + S3
- `/ingest-meeting-notes` — Gemini meeting notes → OpenProject tasks
- WhatsApp command hub (`!status`, `!deadlines`, `!brief`, `!ncr`, `!help`)
- `whatsapp-cmd-hub.py` — polls direct WhatsApp chat for `!command` triggers
- SSM-only EC2 access (no open SSH port)

### Changed
- Desktop menu bar app removed; briefings now invoked directly via `run-scheduled-task.sh` or launchd
- WhatsApp bridge upgraded to v0.3.0 — Bearer token auth required on all bridge API calls
- `run-scheduled-task.sh` migrated from clipboard/Terminal paste model to `claude --print < prompt-file`

### Infrastructure
- EC2: `t4g.xlarge` (arm64, us-east-1f), Amazon Linux 2023, 500GB data EBS
- OpenProject 17.4.1 on Docker (PostgreSQL 16, Memcached, Hocuspocus)
- AXERP (ERPNext v16.23.0) on dedicated MariaDB 10.6 container
- Terraform state for all AWS resources in `infrastructure/terraform/`
