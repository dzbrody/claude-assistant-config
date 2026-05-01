#!/bin/bash
# sync-nextcloud-to-openproject.sh
# One-time migration: copy Nextcloud files to OpenProject S3
# Run this BEFORE decommissioning Nextcloud

set -e

SOURCE_BUCKET="xgccloud-nextcloud"
DEST_BUCKET="axina-openproject-files"

echo "============================================"
echo "  Nextcloud -> OpenProject S3 Migration"
echo "============================================"
echo ""
echo "  Source: s3://${SOURCE_BUCKET}"
echo "  Dest:   s3://${DEST_BUCKET}/nextcloud-migration/"
echo ""
echo "  Files will be copied to a 'nextcloud-migration/'"
echo "  prefix so they don't conflict with OpenProject's"
echo "  own attachment structure."
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  exit 1
fi

echo "Syncing..."
aws s3 sync "s3://${SOURCE_BUCKET}" "s3://${DEST_BUCKET}/nextcloud-migration/"

echo ""
echo "============================================"
echo "  Sync complete. Verification:"
echo "============================================"
echo ""

echo "Source files:"
aws s3 ls "s3://${SOURCE_BUCKET}" --recursive --summarize | tail -2

echo ""
echo "Destination files:"
aws s3 ls "s3://${DEST_BUCKET}/nextcloud-migration/" --recursive --summarize | tail -2

echo ""
echo "If counts match, you can decommission the Nextcloud bucket:"
echo "  ./scripts/decommission-nextcloud.sh"
