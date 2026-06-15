# Pydio Cells VDR — Deployment Guide

Self-hosted Virtual Data Room at `vdr.axinagroup.com`.
Uses existing EC2 instance, shared PostgreSQL, and a dedicated S3 bucket.

---

## Architecture

```
                        HTTPS
Browser ──────────────────────────────► nginx (443)
                                            │
                            ┌───────────────▼─────────────────┐
                            │  cells-app:8080 (Pydio Cells)    │
                            └───┬───────────────┬──────────────┘
                                │               │
                    ┌───────────▼──┐    ┌────────▼──────────┐
                    │  PostgreSQL  │    │ S3: axina-cells-vdr│
                    │  cells DB    │    │  (us-east-1)       │
                    └──────────────┘    └────────────────────┘
                                │
                    ┌───────────▼──────────┐
                    │  cells-clamav:3310   │
                    │  (AV sidecar)        │
                    └──────────────────────┘
```

| Item | Detail |
|------|--------|
| Domain | `vdr.axinagroup.com` — Route53 A → `44.195.198.18` |
| TLS | Let's Encrypt, auto-renewing via shared certbot container |
| Database | `cells` DB + `cells` user on `openproject-postgres` container |
| Storage | S3 `axina-cells-vdr` — IAM user `cells-vdr-s3` |
| Config/data | `/data/cells/config/` on the 100GB EBS data volume |

---

## Phase 1 — Local Validation

### 1.1 Prerequisites

```bash
docker --version    # 24+ recommended
docker compose version  # v2.x
```

### 1.2 Start the local stack

```bash
cd infrastructure/docker

# Optional: override the default dev password
export CELLS_DB_PASSWORD="my_local_dev_pass"

docker compose -f docker-compose.cells-local.yml up -d

# Watch ClamAV pull its virus definitions (~300 MB, first run only)
docker logs cells-local-clamav -f
# Wait until you see: "Clamd successfully started"

docker logs cells-local-app -f
# Wait for: "All services started"
```

### 1.3 Run the web installer

Open **http://localhost:8080** in your browser.

The installer presents a multi-step wizard. Follow the steps below:

---

#### Step A — Database

When the DB form appears, **do not use the MySQL/MariaDB default connection string**.
Switch the driver to **PostgreSQL** by entering the following DSN:

```
postgresql://cells:cells_local_dev@cells-local-postgres:5432/cells?sslmode=disable
```

| Field | Value |
|-------|-------|
| Driver | **PostgreSQL** (select from dropdown, not MySQL) |
| Host | `cells-local-postgres` |
| Port | `5432` |
| Database name | `cells` |
| Username | `cells` |
| Password | `cells_local_dev` (or your `CELLS_DB_PASSWORD` override) |
| SSL Mode | `disable` (local only — production uses the shared postgres with SSL off internally) |

Click **Test Connection** before proceeding. If it fails, verify the postgres container is healthy:

```bash
docker exec cells-local-postgres pg_isready -U cells
```

---

#### Step B — Admin Account

Set the Cells admin username and a strong password. Save these — you will replicate them in production.

---

#### Step C — Storage

At this stage leave storage as **local filesystem** for the local validation run.
You will switch to S3 in production (see Phase 2 §2.4).

---

#### Step D — Complete

The wizard runs migrations and restarts the service. Log in with the admin credentials you set.

---

### 1.4 Verify ClamAV is connected (local)

After Cells is running, navigate to:

**Admin Console → Security → Antivirus**

1. Set **Scanner Type** → `ClamAV`
2. Set **Scanner Address** → `cells-local-clamav:3310`
3. Click **Test** — you should see `OK` returned by the daemon

---

### 1.5 Tear down local stack

```bash
docker compose -f docker-compose.cells-local.yml down -v
```

The `-v` flag removes the local volumes. Omit it if you want to resume the local state.

---

## Phase 2 — Production Deployment on EC2

### 2.1 Pre-deployment: AWS resources

#### 2.1.1 Create the S3 bucket

```bash
aws s3api create-bucket \
  --bucket axina-cells-vdr \
  --region us-east-1

aws s3api put-bucket-versioning \
  --bucket axina-cells-vdr \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket axina-cells-vdr \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-public-access-block \
  --bucket axina-cells-vdr \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

#### 2.1.2 Create the IAM user and attach the policy

```bash
# Create user
aws iam create-user --user-name cells-vdr-s3

# Attach the scoped policy (file is at infrastructure/docker/cells-iam-policy.json)
aws iam create-policy \
  --policy-name CellsVDRBucketPolicy \
  --policy-document file://infrastructure/docker/cells-iam-policy.json

aws iam attach-user-policy \
  --user-name cells-vdr-s3 \
  --policy-arn arn:aws:iam::<ACCOUNT_ID>:policy/CellsVDRBucketPolicy

# Create access key — save the output immediately, it is shown only once
aws iam create-access-key --user-name cells-vdr-s3
```

Copy `AccessKeyId` → `CELLS_S3_ACCESS_KEY_ID`
Copy `SecretAccessKey` → `CELLS_S3_SECRET_ACCESS_KEY`

#### 2.1.3 Route53 — add vdr subdomain

```bash
# Already points to 44.195.198.18 (same Elastic IP as projects.axinagroup.com)
# If not yet created:
aws route53 change-resource-record-sets \
  --hosted-zone-id <YOUR_ZONE_ID> \
  --change-batch '{
    "Changes":[{
      "Action":"UPSERT",
      "ResourceRecordSet":{
        "Name":"vdr.axinagroup.com",
        "Type":"A",
        "TTL":300,
        "ResourceRecords":[{"Value":"44.195.198.18"}]
      }
    }]
  }'
```

---

### 2.2 Provision the Cells database on the shared PostgreSQL container

```bash
aws ssm start-session --target i-07bb8581203e52527

# Create DB and user inside the running postgres container
docker exec -it openproject-postgres psql -U openproject -c \
  "CREATE USER cells WITH PASSWORD '<CELLS_DB_PASSWORD>';"

docker exec -it openproject-postgres psql -U openproject -c \
  "CREATE DATABASE cells OWNER cells;"
```

---

### 2.3 Configure production .env

On the server, add the Cells block to `/opt/openproject/.env`:

```bash
aws ssm start-session --target i-07bb8581203e52527

cat >> /opt/openproject/.env << 'EOF'

# ---- Pydio Cells VDR ----
CELLS_DOMAIN=vdr.axinagroup.com
CELLS_DB_PASSWORD=<generated_with_openssl_rand_hex_32>
CELLS_S3_ACCESS_KEY_ID=<from_iam_create_access_key>
CELLS_S3_SECRET_ACCESS_KEY=<from_iam_create_access_key>
CELLS_S3_BUCKET=axina-cells-vdr
CELLS_S3_REGION=us-east-1
EOF

chmod 600 /opt/openproject/.env
```

---

### 2.4 Provision the EBS data directory

```bash
mkdir -p /data/cells/config
```

---

### 2.5 Issue the TLS certificate for vdr.axinagroup.com

The certbot container is already running. Stop it temporarily, issue the cert, then restart:

```bash
cd /opt/openproject

# Issue cert (webroot method via the shared certbot-www volume)
# nginx must be serving HTTP on port 80 for vdr.axinagroup.com first — the nginx.conf
# already has the HTTP redirect server block covering both domains.
docker compose exec certbot certbot certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  -d vdr.axinagroup.com \
  --email <LETSENCRYPT_EMAIL> \
  --agree-tos \
  --non-interactive

# Reload nginx to pick up the new cert
docker compose exec nginx nginx -s reload
```

Verify:

```bash
curl -I https://vdr.axinagroup.com
# Expect: HTTP/2 200 (or 302 redirect to installer)
```

---

### 2.6 Deploy Cells

```bash
cd /opt/openproject

# Pull latest image
docker compose pull cells

# Start Cells and ClamAV sidecar
docker compose up -d cells-clamav cells

# Watch startup
docker logs cells-app -f
# Wait for: "All services started"
```

---

### 2.7 Run the production installer

Open **https://vdr.axinagroup.com** in your browser.

#### Step A — Database

Use the PostgreSQL driver with the production DSN:

```
postgresql://cells:<CELLS_DB_PASSWORD>@openproject-postgres:5432/cells?sslmode=disable
```

`openproject-postgres` resolves within the shared Docker bridge network because both services are defined in the same `docker-compose.yml` and use the default network.

---

#### Step B — Admin Account

Set a strong admin password. Store in 1Password as **Cells VDR Admin**.

---

#### Step C — S3 Datasource

During the installer's storage step, or post-install via **Admin Console → Storage → Datasources → + Add datasource**:

| Field | Value |
|-------|-------|
| Datasource type | `Amazon S3` |
| Bucket name | `axina-cells-vdr` |
| Region | `us-east-1` |
| Access Key ID | `<CELLS_S3_ACCESS_KEY_ID>` |
| Secret Access Key | `<CELLS_S3_SECRET_ACCESS_KEY>` |
| Storage prefix (optional) | `cells-data/` |

Click **Test Connection** — a `✓ Bucket accessible` response confirms IAM permissions are correct.

Set this datasource as the **default storage** so all new workspaces write to S3.

---

#### Step D — Complete

Cells runs migrations, then restarts. Log in with your admin credentials.

---

### 2.8 Activate ClamAV antivirus

Navigate to **Admin Console → Security → Antivirus**:

| Field | Value |
|-------|-------|
| Scanner Type | `ClamAV` |
| Scanner Address | `cells-clamav:3310` |

Click **Test** to verify the daemon is reachable. Then:

1. Go to **Scheduler → Add Job → Scan files**
2. Set scope to **All Workspaces**
3. Set schedule (e.g. daily at 02:00)

For real-time scanning on upload:

Navigate to **Flows → Add Flow**:
- Trigger: `Upload` (any workspace)
- Action: `AntiVirus Scan`
- On Virus Found: `Move to quarantine folder` or `Delete`

---

### 2.9 Post-deployment verification

```bash
# 1. Check all containers are healthy
docker ps --filter "name=cells"

# 2. Upload a test file via browser and confirm it lands in S3
aws s3 ls s3://axina-cells-vdr/cells-data/ --recursive

# 3. Test ClamAV with EICAR test string
# In Admin Console → Security → Antivirus → upload the EICAR test file
# It should be quarantined, not stored

# 4. Verify TLS
curl -sI https://vdr.axinagroup.com | grep -E "HTTP|Strict"
```

---

## Maintenance

### Update Cells

```bash
cd /opt/openproject
docker compose pull cells
docker compose up -d cells
```

Cells runs DB migrations automatically on startup.

### Backup

Cells config and state live at `/data/cells/config/` on the EBS volume — covered by the existing `backup-to-s3.sh` script if its path list includes `/data/cells/`.

Add to the backup script on EC2:

```bash
tar czf /tmp/cells-config-$(date +%F).tar.gz /data/cells/config/
aws s3 cp /tmp/cells-config-$(date +%F).tar.gz \
  s3://axina-openproject-files/backups/cells/
```

S3 data is versioned (enabled above) — no additional backup step needed for file content.

### Logs

```bash
docker logs cells-app --tail 100 -f
docker logs cells-clamav --tail 50 -f
```

---

## Security Notes

- `cells-app` binds to `127.0.0.1:8090` on the host — not reachable directly from the internet
- All external access via nginx HTTPS on port 443
- S3 bucket has public access fully blocked; only the `cells-vdr-s3` IAM user can read/write
- ClamAV sidecar runs in the same Docker network, accessible only as `cells-clamav:3310`
- Cells admin password stored in 1Password as **Cells VDR Admin**
- S3 IAM keys stored in `/opt/openproject/.env` (chmod 600), and in 1Password as **Cells VDR S3 Keys**
