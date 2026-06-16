# Nextcloud Deployment Guide

Nextcloud Community Edition on the existing EC2 instance, using Amazon S3 as primary storage and the shared `openproject-postgres` container as the database backend. Served at `files.axinagroup.com`.

---

## Architecture

```
Browser HTTPS
     │
     ▼
nginx (files.axinagroup.com:443)
     │
     ▼
nextcloud-app:80  (port 8091 internal)
     │         │
     │         ├── openproject-postgres:5432  (nextcloud DB)
     │         ├── nextcloud-redis:6379       (APCu + lock cache)
     │         └── S3: axina-nextcloud-files  (primary file store — no local disk)
     │
nextcloud-cron  (background jobs every 5 min)
```

| Item | Detail |
|------|--------|
| Domain | `files.axinagroup.com` — Route53 A → `44.195.198.18` ✅ created 2026-06-16 |
| TLS | Let's Encrypt via shared certbot container — cert to be issued on first deploy |
| Database | `nextcloud` DB on shared `openproject-postgres` |
| Storage | S3 `axina-nextcloud-files` — IAM user `nextcloud-s3` |
| Config | `nextcloud-config` Docker named volume → `/data/docker/volumes/` |
| Hooks | `/data/nextcloud/hooks/` on EBS data volume |
| OpenProject integration | OAuth 2.0 two-way; `files.axinagroup.com` → `projects.axinagroup.com` |

---

## Phase 1 — AWS Pre-requisites

### 1.0 Route53 DNS — files.axinagroup.com ✅ Already done

The A record was created on 2026-06-16 (hosted zone `Z03662342MPWYW6ZEPJLC`):

```bash
# Verify (already INSYNC):
aws route53 list-resource-record-sets \
  --hosted-zone-id Z03662342MPWYW6ZEPJLC \
  --query "ResourceRecordSets[?Name=='files.axinagroup.com.']" \
  --output table

# Live DNS check:
dig +short files.axinagroup.com
# Expected: 44.195.198.18
```

### 1.1 Create S3 Bucket

```bash
aws s3api create-bucket \
  --bucket axina-nextcloud-files \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket axina-nextcloud-files \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket axina-nextcloud-files \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

aws s3api put-public-access-block \
  --bucket axina-nextcloud-files \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### 1.2 Create IAM User and Keys

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws iam create-user --user-name nextcloud-s3

aws iam create-policy \
  --policy-name NextcloudS3Policy \
  --policy-document file://infrastructure/nextcloud/nextcloud-iam-policy.json \
  --query 'Policy.Arn' --output text

aws iam attach-user-policy \
  --user-name nextcloud-s3 \
  --policy-arn "arn:aws:iam::${ACCOUNT_ID}:policy/NextcloudS3Policy"

# Save output immediately — secret shown only once
aws iam create-access-key --user-name nextcloud-s3
```

### 1.3 Route53 — add files subdomain

```bash
aws route53 change-resource-record-sets \
  --hosted-zone-id <YOUR_ZONE_ID> \
  --change-batch '{
    "Changes":[{
      "Action":"UPSERT",
      "ResourceRecordSet":{
        "Name":"files.axinagroup.com",
        "Type":"A",
        "TTL":300,
        "ResourceRecords":[{"Value":"44.195.198.18"}]
      }
    }]
  }'
```

---

## Phase 2 — EC2 Setup

### 2.1 Create Nextcloud database and user

```bash
aws ssm start-session --target i-07bb8581203e52527

docker exec openproject-postgres psql -U openproject -c \
  "CREATE USER nextcloud WITH PASSWORD '<NC_DB_PASSWORD>';"

docker exec openproject-postgres psql -U openproject -c \
  "CREATE DATABASE nextcloud OWNER nextcloud;"
```

### 2.2 Create hook and config directories

```bash
mkdir -p /data/nextcloud/hooks
mkdir -p /data/nextcloud/config

# Copy S3 hook script
aws s3 cp s3://axina-openproject-files/deploy/s3-objectstore.sh \
  /data/nextcloud/hooks/s3-objectstore.sh
chmod +x /data/nextcloud/hooks/s3-objectstore.sh

# Copy Redis config (placed in named volume after first boot — see §2.5)
aws s3 cp s3://axina-openproject-files/deploy/redis.config.php \
  /data/nextcloud/config/redis.config.php
```

### 2.3 Add Nextcloud secrets to .env

Append to `/opt/openproject/.env`:

```bash
cat >> /opt/openproject/.env << 'EOF'

# ---- Nextcloud ----
NC_DB_PASSWORD=<generated_with_openssl_rand_hex_32>
NC_ADMIN_PASSWORD=<generated_with_openssl_rand_hex_16>
NC_S3_BUCKET=axina-nextcloud-files
NC_S3_REGION=us-east-1
NC_S3_ACCESS_KEY_ID=<from_iam_create_access_key>
NC_S3_SECRET_ACCESS_KEY=<from_iam_create_access_key>
EOF
chmod 600 /opt/openproject/.env
```

### 2.4 Deploy Nextcloud containers

```bash
cd /opt/openproject

# Copy compose file (or pull from S3)
aws s3 cp s3://axina-openproject-files/deploy/docker-compose.nextcloud.yml \
  /opt/openproject/docker-compose.nextcloud.yml

# Start
docker compose -f docker-compose.nextcloud.yml up -d

# Watch first-run (S3 hook fires here, then installer runs)
docker logs nextcloud-app -f
# Wait for: "Apache started" — indicates installer completed
```

### 2.5 Copy Redis config into named volume

After the installer completes (Apache started log line), copy the Redis config:

```bash
docker cp /data/nextcloud/config/redis.config.php \
  nextcloud-app:/var/www/html/config/redis.config.php

docker exec nextcloud-app chown www-data:www-data \
  /var/www/html/config/redis.config.php

docker restart nextcloud-app
```

### 2.6 Deploy updated nginx.conf and issue TLS certificate

The `nginx.conf` in this repo already includes the `files.axinagroup.com` server block
and the `upstream nextcloud` entry. Deploy it before issuing the cert so the ACME
HTTP-01 challenge can be served.

```bash
# Upload updated nginx.conf to S3
aws s3 cp infrastructure/docker/nginx.conf \
  s3://axina-openproject-files/deploy/nginx.conf

# Pull to EC2 and restart nginx
aws ssm start-session --target i-07bb8581203e52527
cd /opt/openproject
aws s3 cp s3://axina-openproject-files/deploy/nginx.conf /opt/openproject/nginx.conf

# nginx needs to start without the TLS cert — temporarily comment out the
# files.axinagroup.com 443 block, reload, then issue the cert, then uncomment.
# Easier: issue cert first via standalone mode while nginx is serving port 80.
docker compose restart openproject-nginx
docker compose run --rm certbot certonly \
  --webroot --webroot-path /var/www/certbot \
  -d files.axinagroup.com \
  --email db@xgccorp.com \
  --agree-tos --non-interactive
```

Reload nginx to activate the HTTPS block with the new cert:

```bash
docker exec openproject-nginx nginx -t
docker exec openproject-nginx nginx -s reload
```

Verify:

```bash
curl -sI https://files.axinagroup.com | grep -E "HTTP|Location|Server"
# Expect: HTTP/2 200 (or 302 to /login)

# Check cert subject
echo | openssl s_client -connect files.axinagroup.com:443 \
  -servername files.axinagroup.com 2>/dev/null \
  | openssl x509 -noout -subject -dates
# Expected: subject=CN=files.axinagroup.com
```

---

## Phase 3 — Validation Checkpoints

### 3.1 S3 connectivity

```bash
# From inside the container
docker exec nextcloud-app php occ files:scan --all

# Check a file actually landed in S3
aws s3 ls s3://axina-nextcloud-files/ --recursive | head -10
```

### 3.2 Database connectivity

```bash
docker exec nextcloud-app php occ db:convert-type pgsql nextcloud \
  openproject-postgres 5432 nextcloud 2>&1 | head -5
# Expected: "Already using PostgreSQL" or clean output (not an error)

# Direct check
docker exec openproject-postgres psql -U openproject -d nextcloud \
  -c "\dt" | head -20
# Should show Nextcloud tables (oc_accounts, oc_filecache, etc.)
```

### 3.3 Redis cache

```bash
docker exec nextcloud-app php occ config:system:get memcache.distributed
# Expected: \OC\Memcache\Redis

docker exec nextcloud-redis redis-cli info clients | grep connected_clients
# Expected: connected_clients:N  (N > 0 once Nextcloud connects)
```

### 3.4 Background cron

```bash
docker logs nextcloud-cron --tail 5
# Expected: "Nextcloud cron execution" lines every 5 minutes

docker exec nextcloud-app php occ background:cron
# Manually trigger once to verify
```

### 3.5 Overall health

```bash
docker exec nextcloud-app php occ status
# Expected:
#   installed: true
#   version: 30.x.x
#   versionstring: Nextcloud 30.x.x
#   edition:
#   maintenance: false
```

### 3.6 Permissions check

```bash
docker exec nextcloud-app php occ check
# Must return no errors. Common warnings:
# "No memory cache configured" — fixed by Redis config in §2.5
# "The PHP OPcache is not properly configured" — acceptable on first run
```

---

## Phase 4 — OpenProject Integration (OAuth 2.0)

Reference: https://www.youtube.com/watch?v=nPEFYicyHpI

This connects Nextcloud to OpenProject so users can link files directly to work packages, and project folders are auto-created on Nextcloud.

### 4.1 Install OpenProject Integration app in Nextcloud

```bash
# Via occ CLI (recommended — no GUI needed)
docker exec -u www-data nextcloud-app php occ app:install integration_openproject

# Enable it
docker exec -u www-data nextcloud-app php occ app:enable integration_openproject

# Verify
docker exec -u www-data nextcloud-app php occ app:list | grep openproject
# Expected: integration_openproject: X.Y.Z
```

### 4.2 Configure OAuth 2.0 on OpenProject side

**In OpenProject admin panel** (`https://projects.axinagroup.com/admin`):

1. Go to **Administration → Authentication → OAuth applications → + New application**
2. Fill in:
   - **Name**: `Nextcloud`
   - **Redirect URI**: `https://files.axinagroup.com/apps/integration_openproject/oauth-redirect`
   - **Client credentials**: check **"Confidential"**
3. Click **Create**. Copy the **Client ID** and **Client secret** — needed in §4.3.
4. Go to **Administration → Files → External file storages → + Storage**:
   - **Storage type**: Nextcloud
   - **Storage name**: `Axina Nextcloud`
   - **Nextcloud URL**: `https://files.axinagroup.com`
   - **OpenProject OAuth application**: select the one created above
   - **Automatically managed folders**: ✅ Enable
5. Click **Save**. OpenProject will display a **Nextcloud OAuth app** Client ID + Secret — copy these for §4.3.

### 4.3 Configure OAuth 2.0 on Nextcloud side

**In Nextcloud admin panel** (`https://files.axinagroup.com/settings/admin/openproject`):

1. Go to **Administration → OpenProject Integration**
2. Fill in:
   - **OpenProject host**: `https://projects.axinagroup.com`
   - **Client ID**: (from OpenProject OAuth app in §4.2)
   - **Client secret**: (from OpenProject OAuth app in §4.2)
3. Click **Save**. The page will redirect to OpenProject to authorize.
4. After authorization, return to Nextcloud and also fill the **Nextcloud OAuth credentials** section:
   - **Client ID** and **Client secret**: (the values OpenProject generated in §4.2 step 5)
5. Click **Save**.

### 4.4 Verify the OAuth handshake

```bash
# Check integration app reports connected
docker exec -u www-data nextcloud-app php occ config:app:get \
  integration_openproject openproject_instance_url
# Expected: https://projects.axinagroup.com

docker exec -u www-data nextcloud-app php occ config:app:get \
  integration_openproject token_type
# Expected: Bearer
```

### 4.5 Enable project folder auto-management

Back in OpenProject **Administration → Files → External file storages → Axina Nextcloud**:

1. Confirm **Automatically managed project folders** is ON.
2. OpenProject will create `/OpenProject/<project-name>/` folders on Nextcloud automatically when projects have the Files module enabled.
3. Enable the **Files module** per project: **Project → Settings → Modules → check Files** → Save.

Once enabled, every work package detail panel will show a **Files** tab where users can attach or link Nextcloud files directly.

---

## Maintenance

### Update Nextcloud

```bash
cd /opt/openproject
docker compose -f docker-compose.nextcloud.yml pull nextcloud
docker compose -f docker-compose.nextcloud.yml up -d nextcloud nextcloud-cron
docker exec -u www-data nextcloud-app php occ upgrade
docker exec -u www-data nextcloud-app php occ maintenance:mode --off
```

### Backup

Nextcloud files are in S3 (versioned — no additional backup needed for file content).
Config volume:

```bash
docker run --rm \
  -v nextcloud-config:/data \
  -v /tmp:/backup \
  alpine tar czf /backup/nextcloud-config-$(date +%F).tar.gz /data

aws s3 cp /tmp/nextcloud-config-$(date +%F).tar.gz \
  s3://axina-openproject-files/backups/nextcloud/
```

### Logs

```bash
docker logs nextcloud-app --tail 100 -f
docker logs nextcloud-cron --tail 20
docker logs nextcloud-redis --tail 10
```

---

## Security Notes

- `nextcloud-app` binds to `127.0.0.1:8091` only — not reachable from internet directly
- S3 bucket has public access fully blocked; only `nextcloud-s3` IAM user can read/write
- Redis binds only within `openproject_default` Docker network
- Nextcloud admin password stored in 1Password as **Nextcloud Admin**
- S3 IAM keys stored in `/opt/openproject/.env` (chmod 600) and in 1Password as **Nextcloud S3 Keys**
