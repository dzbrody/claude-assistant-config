# Decommission Nextcloud S3 Bucket

Run the Nextcloud decommission script. This PERMANENTLY deletes the `xgccloud-nextcloud` S3 bucket and all its contents.

**Only run this after confirming OpenProject S3 storage is working and migration is complete.**

```bash
bash ~/.claude-assistant/scripts/decommission-nextcloud.sh
```

The script requires typing the bucket name (`xgccloud-nextcloud`) to confirm before deleting anything. It uses a paginated loop to handle >1000 object versions and also clears delete markers before removing the bucket.
