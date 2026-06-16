#!/bin/sh
# /docker-entrypoint-hooks.d/s3-objectstore.sh
#
# Injected into Nextcloud before first-run installer executes.
# Creates /var/www/html/config/s3.config.php with S3 primary objectstore.
# Nextcloud merges all *.config.php files in /var/www/html/config/ at startup.
#
# Storage layout:  s3://axina-openproject-files/nextcloud/<urn>
# Bucket:          axina-openproject-files   (shared with OpenProject)
# Prefix:          nextcloud/                (isolates all Nextcloud objects)
#
# This hook runs BEFORE the web installer so S3 is active from the first login —
# no local data directory is ever written.

set -e

CONFIG_FILE="/var/www/html/config/s3.config.php"

if [ -f "$CONFIG_FILE" ]; then
  echo "[hook] s3.config.php already exists — skipping"
  exit 0
fi

echo "[hook] Writing S3 primary objectstore config..."

cat > "$CONFIG_FILE" << PHPEOF
<?php
\$CONFIG = array(
  'objectstore' => array(
    'class'     => '\\OC\\Files\\ObjectStore\\S3',
    'arguments' => array(
      'bucket'          => '${NC_S3_BUCKET}',
      'prefix'          => 'nextcloud/',
      'autocreate'      => false,
      'key'             => '${NC_S3_KEY}',
      'secret'          => '${NC_S3_SECRET}',
      'region'          => '${NC_S3_REGION}',
      'use_ssl'         => true,
      'use_path_style'  => false,
    ),
  ),
  // Disable local filesystem quota enforcement (irrelevant with S3)
  'quota_include_external_storage' => false,
  // Raise upload limit to match nginx (5GB)
  'max_chunk_size' => 104857600,
);
PHPEOF

chown www-data:www-data "$CONFIG_FILE"
chmod 640 "$CONFIG_FILE"
echo "[hook] s3.config.php written — bucket: ${NC_S3_BUCKET}/nextcloud/"
