# Infrastructure — Claude Code Instructions

This directory tracks infrastructure-as-code for CTO Rescues production services on EC2.

## Host

**EC2 YOUR_INSTANCE_ID** — t4g.xlarge, arm64 Graviton2, us-east-1f, 500GB EBS
- Access: **AWS SSM only** — no SSH. Use `aws ssm send-command`.
- SSM escape rule: complex scripts → write to `/tmp/`, upload to S3, download and run on EC2.
- S3 deploy bucket: `s3://ctorescues-openproject-files/deploy/`

## Services on this host

| Service | Domain | Compose file | Port |
|---------|--------|-------------|------|
| ERP (ERPNext) | erp.ctorescues.com | `docker/docker-compose.axerp.yml` | 8082→8080 |
| OpenProject | projects.ctorescues.com | `/opt/openproject/docker-compose.yml` | managed by nginx |
| Nextcloud | files.ctorescues.com | `docker/docker-compose.nextcloud.yml` | managed by nginx |
| Nginx (reverse proxy) | all domains | inside `docker-compose.yml` | 80/443 |

All services share the `openproject_default` Docker network.

## ERP — see docker/CLAUDE.md for full details

The compose file at `docker/docker-compose.axerp.yml` is the source of truth.
After any change: `aws s3 cp docker/docker-compose.axerp.yml s3://ctorescues-openproject-files/deploy/`

**Current image:** `axerp:v16.23.0-axerp.3`
**Apps:** frappe 16.23.0, erpnext 16.23.0, hrms 16.9.0, crm 1.73.2, insights 3.3.1
**DB:** MariaDB 10.6 (container `axerp-mariadb`) — NOT the shared PostgreSQL instance

## Post-deploy asset sync (ERP)

Every time the ERP image is redeployed, run this to fix assets.json hash mismatch:

```bash
# Via SSM (upload script to S3 first):
aws s3 cp s3://ctorescues-openproject-files/deploy/axerp-fix-assets-json.sh /tmp/axerp-fix-assets-json.sh
bash /tmp/axerp-fix-assets-json.sh
```

This rebuilds frappe on the live backend and syncs `frappe/dist/`, `erpnext/dist/`, and
`assets.json` to the frontend container. Takes ~30 seconds. Required because the frappe
entrypoint resets the assets symlink on every container start.

## Deploying a new ERP image

1. Build on EC2 using `axerp-build-v3b.sh` (on S3): packages source, runs `docker build`, `docker compose up -d`
2. Run `axerp-fix-assets-json.sh` after deploy
3. Verify: `curl -sk -o /dev/null -w "%{http_code}" https://erp.ctorescues.com/`

Do NOT use `--remove-orphans` on `docker compose up` — it stops OpenProject and Nextcloud.

## Nginx (outer reverse proxy)

The `openproject-nginx` container handles TLS termination and routing:
- `projects.ctorescues.com` → `openproject-app:8080`
- `files.ctorescues.com` → `nextcloud-app:80`
- `erp.ctorescues.com` → `axerp-frontend:8080`
- `erp.*.com/socket.io/` → `axerp-websocket:9000` (WebSocket, 86400s timeout)

TLS: ctorescues.com domains use Let's Encrypt (auto-renewed by `openproject-certbot`).

## .env on EC2

`/opt/openproject/.env` (chmod 600) — contains all secrets:
- `AXERP_DB_ROOT_PASSWORD`, `AXERP_ADMIN_PASSWORD`, `AXERP_SITE_NAME`
- OpenProject and Nextcloud secrets
- `OPENPROJECT_MAIL_FROM`, `SMTP_DOMAIN`, `NC_MAIL_DOMAIN` (ctorescues.com mail vars)

Never commit `.env` to git. Stored in 1Password.
