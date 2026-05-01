#!/bin/bash
# decommission-nextcloud.sh
# Run AFTER confirming OpenProject S3 storage works and migration is complete

set -e

BUCKET="xgccloud-nextcloud"

echo "============================================"
echo "  Decommission Nextcloud S3 Bucket"
echo "============================================"
echo ""
echo "  This will PERMANENTLY DELETE:"
echo "  s3://${BUCKET}"
echo "  ALL objects in it"
echo "  ALL versions"
echo ""

read -p "Are you ABSOLUTELY sure? Type the bucket name to confirm: " CONFIRM

if [ "$CONFIRM" != "$BUCKET" ]; then
  echo "Confirmation failed. Aborting."
  exit 1
fi

echo ""
echo "Deleting all objects and versions..."
aws s3api delete-objects \
  --bucket "$BUCKET" \
  --delete "$(aws s3api list-object-versions \
    --bucket "$BUCKET" \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json)" || true

echo "Removing bucket..."
aws s3 rb "s3://${BUCKET}" --force

echo ""
echo "Nextcloud bucket deleted."
echo ""
echo "Now remove any Nextcloud references from:"
echo "  - IAM policies referencing xgccloud-nextcloud"
echo "  - Application configs"
echo "  - DNS records (if any)"
echo "  - EC2 mount points or fstab entries"
