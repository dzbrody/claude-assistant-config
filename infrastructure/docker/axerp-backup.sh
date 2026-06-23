#!/bin/bash
# axerp-backup.sh — Daily ERPNext backup to S3
# Runs as a cron job on EC2. Backs up:
#   1. MariaDB dump (via bench backup)
#   2. Sites directory (config, private files)
#
# Cron: 0 2 * * * /opt/openproject/scripts/axerp-backup.sh >> /var/log/axerp-backup.log 2>&1
#
# Retention handled by S3 Lifecycle on ctorescues-openproject-files:
#   7d  STANDARD → 90d STANDARD_IA → 365d GLACIER  (same policy as OpenProject backups)

set -euo pipefail

SITE="erp.ctorescues.com"
S3_BUCKET="ctorescues-openproject-files"
S3_PREFIX="backups/axerp"
DATE=$(date +%Y/%m/%d)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/data/axerp/backups"

mkdir -p "$BACKUP_DIR"

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] === ERP Backup Start ==="

# ── 1. bench backup (MariaDB dump + private files) ──────────────────────────
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Running bench backup..."
docker exec axerp-backend bench --site "$SITE" backup --backup-path /home/frappe/frappe-bench/sites/backups 2>&1

# Copy bench backup files out of the container
docker cp "axerp-backend:/home/frappe/frappe-bench/sites/backups/." "$BACKUP_DIR/" 2>/dev/null || true

# ── 2. Sites directory snapshot (config + custom files) ─────────────────────
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Archiving sites directory..."
SITES_ARCHIVE="${BACKUP_DIR}/sites_${TIMESTAMP}.tar.gz"
tar -czf "$SITES_ARCHIVE" \
  --exclude="/data/axerp/sites/backups" \
  --exclude="/data/axerp/sites/assets" \
  /data/axerp/sites/ 2>/dev/null || true

# ── 3. Upload to S3 ──────────────────────────────────────────────────────────
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Uploading to s3://${S3_BUCKET}/${S3_PREFIX}/${DATE}/..."
aws s3 sync "$BACKUP_DIR/" "s3://${S3_BUCKET}/${S3_PREFIX}/${DATE}/" \
  --exclude "*" \
  --include "*.sql.gz" \
  --include "*.tar.gz" \
  --storage-class STANDARD \
  --only-show-errors

# ── 4. Cleanup local backups older than 3 days ───────────────────────────────
find "$BACKUP_DIR" -name "*.sql.gz" -mtime +3 -delete 2>/dev/null || true
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +3 -delete 2>/dev/null || true

echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] === ERP Backup Complete ==="

# ── 5. Verify latest backup exists in S3 ─────────────────────────────────────
COUNT=$(aws s3 ls "s3://${S3_BUCKET}/${S3_PREFIX}/${DATE}/" --recursive | wc -l)
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Files in S3 for today: ${COUNT}"
