# ERP Deployment Guide

ERPNext v16 (ERP fork) on EC2 with PostgreSQL, served at `erp.ctorescues.com`.

## Architecture

```
Browser → nginx (443) → axerp-frontend:8080 → axerp-backend:8000
                                              ↘ axerp-websocket:9000 (Socket.IO)
Database: openproject-postgres (PostgreSQL 16) — separate DB and role created by bench
Cache:    axerp-redis-cache:6379
Queue:    axerp-redis-queue:6379
Network:  openproject_default (shared with OpenProject and Nextcloud)
```

- **Image**: Built from your ERP fork on top of `frappe/erpnext:v16.13.3`
- **Platform**: `linux/arm64` (Graviton2 EC2)
- **Port**: `127.0.0.1:8082:8080` (internal to EC2 — nginx is the only public entry point)

## Phase 1: AWS Pre-requisites

### 1.1 Route53 DNS

```bash
# Get the hosted zone ID (same zone as projects.ctorescues.com)
aws route53 list-hosted-zones-by-name --dns-name ctorescues.com \
  --query "HostedZones[0].Id" --output text

# Create A record: erp.ctorescues.com → YOUR_EC2_ELASTIC_IP
aws route53 change-resource-record-sets \
  --hosted-zone-id <zone-id> \
  --change-batch '{
    "Changes": [{
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": "erp.ctorescues.com",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value": "YOUR_EC2_ELASTIC_IP"}]
      }
    }]
  }'
```

Wait ~60 seconds for propagation: `dig +short erp.ctorescues.com`

## Phase 2: Build & Deploy on EC2

Connect via SSM:
```bash
aws ssm start-session --target YOUR_INSTANCE_ID
```

### 2.1 Clone and Build the Image

```bash
# Clone to data volume (not root)
sudo git clone https://github.com/your-org/axerp.git /data/axerp-src
cd /data/axerp-src
sudo git checkout version-16

# Build the production image (arm64 native — no cross-compilation needed)
cd /data/axerp-src
sudo docker build -f docker/Dockerfile -t axerp:prod .
# Build takes ~5–10 minutes (pip install + bench build for frontend assets)
```

### 2.2 Create Data Directories

```bash
sudo mkdir -p /data/axerp/sites /data/axerp/logs /data/axerp/redis-queue
sudo chown -R 1000:1000 /data/axerp  # frappe UID inside the container
```

### 2.3 Add Secrets to .env

```bash
cd /opt/openproject

# Generate ERP admin password
AXERP_ADMIN_PASSWORD=$(openssl rand -hex 16)
echo "AXERP_SITE_NAME=erp.ctorescues.com" >> .env
echo "AXERP_ADMIN_PASSWORD=$AXERP_ADMIN_PASSWORD" >> .env
chmod 600 .env

echo "=== Save this admin password in 1Password as 'ERP Admin' ==="
echo "$AXERP_ADMIN_PASSWORD"
```

> **Note:** `create-site` uses `OPENPROJECT_DB_PASSWORD` (already in `.env`) as the PostgreSQL superuser password. The `openproject` DB user is a PG superuser and can create new databases/roles — no separate root DB account needed.

### 2.4 Deploy the Stack

```bash
cd /opt/openproject

# Copy compose file from S3 (if not already present)
aws s3 cp s3://ctorescues-openproject-files/deploy/docker-compose.axerp.yml .

# Start everything (create-site runs once and exits)
docker compose -f docker-compose.axerp.yml up -d

# Watch site creation (takes 5–15 minutes)
docker logs axerp-create-site -f
# Success message: "Site creation complete." + container exits 0
```

### 2.5 Issue TLS Certificate

```bash
# Nginx must be running and erp.ctorescues.com must already resolve to this IP
docker exec openproject-nginx nginx -s reload

docker exec openproject-certbot certbot certonly \
  --webroot \
  --webroot-path /var/www/certbot \
  -d erp.ctorescues.com \
  --email admin@ctorescues.com \
  --agree-tos \
  --non-interactive

# Reload nginx to pick up the new cert
docker exec openproject-nginx nginx -s reload
```

### 2.6 Post-Creation: Restart Workers

After `create-site` exits successfully, restart the services that need the freshly created site files:

```bash
cd /opt/openproject
docker compose -f docker-compose.axerp.yml restart backend queue-long queue-short scheduler
```

## Phase 3: Validation

```bash
# All ERP containers should be running (create-site will show Exited 0)
docker ps --filter "name=axerp"

# Check backend is serving
curl -sk https://erp.ctorescues.com/api/method/frappe.ping | jq .
# Expected: {"message": "pong"}

# Check PostgreSQL — ERP DB should exist
docker exec openproject-postgres psql -U openproject -c "\l" | grep erp
# Expected: erp.ctorescues.com | openproject_erp_... | UTF8 | ...

# Check Redis queues
docker exec axerp-redis-queue redis-cli ping   # PONG
docker exec axerp-redis-cache redis-cli ping   # PONG

# Check logs for errors
docker logs axerp-backend --tail 50
docker logs axerp-queue-long --tail 20
```

Expected: `https://erp.ctorescues.com` loads the ERPNext login page.
Default credentials: `Administrator` / `<ERP_ADMIN_PASSWORD>` (set in `.env`).

## Phase 4: Initial ERPNext Setup

1. Log in at `https://erp.ctorescues.com` as `Administrator`
2. Complete the Setup Wizard:
   - Country: your primary country
   - Currency: USD (or as needed)
   - Time zone: America/New_York
   - Chart of Accounts: standard
3. Enable modules needed: Accounts, Projects, HR, Purchasing, Selling
4. Create company: **CTO Rescues**

## Maintenance

### Update ERP (pull latest from GitHub)

```bash
aws ssm start-session --target YOUR_INSTANCE_ID

cd /data/axerp-src
sudo git pull
sudo git checkout version-16

# Rebuild image
sudo docker build -f docker/Dockerfile -t axerp:prod .

# Rolling restart (sites volume preserved — no data loss)
cd /opt/openproject
docker compose -f docker-compose.axerp.yml up -d --no-deps --build frontend backend queue-long queue-short scheduler websocket
```

### Logs

```bash
docker logs axerp-backend --tail 100 -f
docker logs axerp-queue-long --tail 50
docker logs axerp-frontend --tail 50
```

### Run bench commands

```bash
docker exec -it axerp-backend bash
bench --site erp.ctorescues.com migrate
bench --site erp.ctorescues.com clear-cache
```

### Stop / remove

```bash
cd /opt/openproject
docker compose -f docker-compose.axerp.yml down
# Data persists in /data/axerp/sites and openproject-postgres
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `create-site` exits 1 with PG error | Wrong DB password in `.env` | Verify `OPENPROJECT_DB_PASSWORD` matches running postgres |
| `create-site` loops on `common_site_config.json` | configurator didn't finish | `docker logs axerp-configurator` — check for errors |
| 502 Bad Gateway | backend not ready yet | Wait 30s after create-site, then `docker compose restart backend` |
| Socket.IO disconnect loop | websocket container not on `openproject_default` | Verify network in `docker inspect axerp-websocket` |
| `bench build` fails during Docker build | npm/node issue in base image | Usually transient — retry `docker build` |
| PG role already exists error | Site partially created | Drop the role in psql then re-run create-site, or use the existing site |

### Reset site (destructive — wipes all ERP data)

```bash
docker exec openproject-postgres psql -U openproject \
  -c "DROP DATABASE IF EXISTS \"erp_ctorescues_com\";"
rm -rf /data/axerp/sites/erp.ctorescues.com


cd /opt/openproject
docker compose -f docker-compose.axerp.yml up axerp-create-site
```
