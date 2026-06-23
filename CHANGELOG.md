# Changelog

All notable changes to this project are documented here.

---

## [Unreleased] — 2026-06-23

### Added — `infrastructure/terraform/tspgusa.tf`

- Route 53 A records for `projects/files/erp.ctorescues.com` → EC2 EIP (YOUR_EC2_ELASTIC_IP)
- SES domain identity for `ctorescues.com` with Easy DKIM (3 CNAMEs auto-provisioned)
- SPF (`v=spf1 include:amazonses.com ~all`) on root and MAIL FROM subdomain
- Custom MAIL FROM (`mail.ctorescues.com`) with MX + SPF for bounce/complaint routing
- DMARC (`p=quarantine`, `rua=dmarc-reports@ctorescues.com`) — upgrade to `p=reject` after validating rua reports
- Secrets Manager placeholders `ctorescues/wildcard-cert` and `ctorescues/wildcard-key` for `*.ctorescues.com` internal CA cert
- IAM policies on `ctorescues-openproject-role`: read cert secrets + send via SES from `@ctorescues.com`
- EIP looked up via `data "aws_eip"` to avoid drifted `aws_eip.openproject` state

### Changed — `infrastructure/docker/nginx.conf`

- Added vhosts for `projects.ctorescues.com`, `files.ctorescues.com`, `erp.ctorescues.com` — all using `*.ctorescues.com` wildcard cert
- `erp.ctorescues.com` rewrites `Host: erp.ctorescues.com` before proxying (Frappe site routing keyed on canonical name)
- HTTP→HTTPS redirect block extended to cover all ctorescues.com subdomains

### Changed — `infrastructure/docker/docker-compose.yml`

- `OPENPROJECT_ADDITIONAL__HOST__NAMES` includes `projects.ctorescues.com`
- `OPENPROJECT_MAIL_FROM` and `OPENPROJECT_SMTP__DOMAIN` now env-var driven (`no-reply@ctorescues.com` default)

### Changed — `infrastructure/docker/docker-compose.nextcloud.yml`

- `NEXTCLOUD_TRUSTED_DOMAINS` includes `files.ctorescues.com`
- `NC_MAIL_DOMAIN` env-var driven (`ctorescues.com` default)

### Changed — `infrastructure/terraform/main.tf`

- S3 CORS `allowed_origins` extended to include `https://projects.ctorescues.com`

### Security — `.gitignore`

- Added `*.tfplan` / `tfplan` patterns — Terraform plan files contain resolved resource values and must not be committed

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
- ERP (ERPNext v16.23.0) on dedicated MariaDB 10.6 container
- Terraform state for all AWS resources in `infrastructure/terraform/`
