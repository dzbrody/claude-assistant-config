#!/bin/bash
# Copyright (c) 2026 Yom Shore Ventures LLC
# dba: CTO Rescues - https://ctorescues.com/
# Author: Daniel Brody (@dzbrody)
#
# Principal Place of Business:
# 8 The Green – Suite 12060
# Dover, Delaware 19901
# United States
#
# All rights reserved. Proprietary and confidential.

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
echo "Deleting all objects and versions (paginated)..."
while true; do
  BATCH=$(aws s3api list-object-versions \
    --bucket "$BUCKET" \
    --max-items 1000 \
    --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' \
    --output json 2>/dev/null)
  COUNT=$(echo "$BATCH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('Objects') or []))")
  if [ "$COUNT" -eq 0 ]; then break; fi
  aws s3api delete-objects --bucket "$BUCKET" --delete "$BATCH"
  echo "  Deleted $COUNT versions..."
done

# Also delete any delete markers
while true; do
  BATCH=$(aws s3api list-object-versions \
    --bucket "$BUCKET" \
    --max-items 1000 \
    --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' \
    --output json 2>/dev/null)
  COUNT=$(echo "$BATCH" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('Objects') or []))")
  if [ "$COUNT" -eq 0 ]; then break; fi
  aws s3api delete-objects --bucket "$BUCKET" --delete "$BATCH"
  echo "  Deleted $COUNT delete markers..."
done

echo "Removing bucket..."
aws s3 rb "s3://${BUCKET}"

echo ""
echo "Nextcloud bucket deleted."
echo ""
echo "Now remove any Nextcloud references from:"
echo "  - IAM policies referencing xgccloud-nextcloud"
echo "  - Application configs"
echo "  - DNS records (if any)"
echo "  - EC2 mount points or fstab entries"
