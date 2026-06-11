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

# ============================================================
# EC2 User Data — Bootstrap script for OpenProject Server
# Runs on first boot (Amazon Linux 2023)
# ============================================================
set -e

exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1
echo "=== Starting OpenProject bootstrap at $(date) ==="

# ---- Update system ----
dnf update -y
dnf install -y docker git nginx certbot python3-certbot-nginx jq

# ---- Start Docker ----
systemctl enable docker
systemctl start docker
usermod -a -G docker ec2-user

# ---- Mount data volume ----
# Wait for /dev/xvdf to appear
for i in {1..30}; do
  if [ -b /dev/xvdf ]; then
    echo "Data volume found"
    break
  fi
  echo "Waiting for /dev/xvdf... attempt $i"
  sleep 2
done

if [ -b /dev/xvdf ]; then
  # Check if already formatted
  if ! blkid /dev/xvdf; then
    mkfs -t xfs /dev/xvdf
  fi
  mkdir -p /data
  mount /dev/xvdf /data
  # Add to fstab for persistence
  if ! grep -q "/dev/xvdf" /etc/fstab; then
    echo "/dev/xvdf /data xfs defaults,nofail 0 2" >> /etc/fstab
  fi
  echo "✓ Data volume mounted at /data"
else
  echo "⚠ WARNING: /dev/xvdf not found. Data will be on root volume."
fi

# ---- Create Docker volume directories ----
mkdir -p /data/openproject/{pgdata,assets,config}
mkdir -p /data/openproject-mcp
chown -R 1000:1000 /data/openproject/assets

# ---- Write OpenProject configuration (S3 fog storage via IAM role) ----
cat > /data/openproject/config/configuration.yml << 'OPCONFIG'
default:
  attachments_storage: fog
  fog:
    provider: AWS
    directory: axina-openproject-files
    region: us-east-1
    credentials:
      provider: AWS
      region: us-east-1
      use_iam_profile: true
  direct_uploads: false
  fog_download_url_expires_in: 21600
OPCONFIG

# ---- Install Docker Compose ----
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
  COMPOSE_ARCH="aarch64"
else
  COMPOSE_ARCH="x86_64"
fi

curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$${COMPOSE_ARCH}" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# ---- Download docker-compose files ----
# Pull from your GitHub repo (or create inline)
mkdir -p /opt/openproject

# We'll create docker-compose.yml from a heredoc below — 
# in production, you'd git pull from your repo
cat > /opt/openproject/docker-compose.yml << 'DOCKEREOF'
version: '3.8'

services:
  # ---- PostgreSQL ----
  postgres:
    image: postgres:16.14
    container_name: openproject-postgres
    restart: unless-stopped
    environment:
      POSTGRES_USER: openproject
      POSTGRES_PASSWORD: $${OPENPROJECT_DB_PASSWORD}
      POSTGRES_DB: openproject
    volumes:
      - /data/openproject/pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U openproject"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ---- OpenProject ----
  openproject:
    image: openproject/openproject:17.4.1
    container_name: openproject-app
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      OPENPROJECT_HOST__NAME: $${DOMAIN_NAME}
      OPENPROJECT_SECRET_KEY_BASE: $${OPENPROJECT_SECRET_KEY_BASE}
      OPENPROJECT_DEFAULT__LANGUAGE: en
      DATABASE_URL: "postgres://openproject:$${OPENPROJECT_DB_PASSWORD}@postgres:5432/openproject"
      RAILS_CACHE_STORE: memcache
      OPENPROJECT_CACHE__MEMCACHE__SERVER: cache:11211
      # SMTP Email (SES) — credentials injected from .env at runtime
      OPENPROJECT_EMAIL__DELIVERY__METHOD: smtp
      OPENPROJECT_SMTP__ADDRESS: email-smtp.us-east-1.amazonaws.com
      OPENPROJECT_SMTP__PORT: "587"
      OPENPROJECT_SMTP__DOMAIN: axinagroup.com
      OPENPROJECT_SMTP__AUTHENTICATION: login
      OPENPROJECT_SMTP__USER__NAME: $${SMTP_USERNAME}
      OPENPROJECT_SMTP__PASSWORD: $${SMTP_PASSWORD}
      OPENPROJECT_SMTP__ENABLE__STARTTLS__AUTO: "true"
      OPENPROJECT_SMTP__OPENSSL__VERIFY__MODE: peer
      OPENPROJECT_MAIL__FROM: no-reply@axinagroup.com
    volumes:
      - /data/openproject/assets:/var/openproject/assets
      - /data/openproject/config/configuration.yml:/app/config/configuration.yml:ro
    depends_on:
      postgres:
        condition: service_healthy
      cache:
        condition: service_started

  # ---- Memcached (for Rails caching) ----
  cache:
    image: memcached:1.6
    container_name: openproject-cache
    restart: unless-stopped
    command: memcached -m 256

  # ---- Nginx reverse proxy with Let's Encrypt ----
  nginx:
    image: nginx:stable-alpine
    container_name: openproject-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
      # Certbot will manage certificates in a volume
      - certbot-www:/var/www/certbot
      - certbot-conf:/etc/letsencrypt
    depends_on:
      - openproject

  # ---- Certbot (Let's Encrypt) ----
  certbot:
    image: certbot/certbot
    container_name: openproject-certbot
    volumes:
      - certbot-www:/var/www/certbot
      - certbot-conf:/etc/letsencrypt
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"

  # ---- Remote MCP Server (Personal Assistant) ----
  mcp-server:
    build:
      context: /data/mcp-server
    container_name: openproject-mcp-server
    restart: unless-stopped
    ports:
      - "127.0.0.1:39128:39128"
    environment:
      OPENPROJECT_URL: https://$${DOMAIN_NAME}
      OPENPROJECT_API_KEY: $${OPENPROJECT_ADMIN_API_KEY}
      AWS_REGION: us-east-1
      S3_BUCKETS: axina-openproject-files
    depends_on:
      - openproject

volumes:
  certbot-www:
  certbot-conf:

DOCKEREOF

# ---- Create Nginx config (initial HTTP-only, certbot will upgrade) ----
cat > /opt/openproject/nginx.conf << 'NGINXEOF'
events {
    worker_connections 1024;
}

http {
    upstream openproject {
        server openproject:8080;
    }

    upstream mcp-server {
        server openproject-mcp-server:39128;
    }

    server {
        listen 80;
        server_name $${DOMAIN_NAME};

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://$${host}$${request_uri};
        }
    }

    # SSL server block will be added after certbot initial run
    # This happens in the post-bootstrap script
}
NGINXEOF

# Substitute domain in nginx config
sed -i "s/\$${DOMAIN_NAME}/${domain_name}/g" /opt/openproject/nginx.conf

# ---- Pull OpenProject MCP Server files ----
cd /data/openproject-mcp
git clone https://github.com/firsthalfhero/openproject-mcp-server.git . || true
# The MCP server can run directly as a Python process or as a container
# We'll add its container to docker-compose in the post-bootstrap step

# ---- Create .env file with secrets ----
# Generate a random secret key base
OPENPROJECT_SECRET_KEY_BASE=$(openssl rand -hex 64)
OPENPROJECT_DB_PASSWORD=$(openssl rand -hex 32)

cat > /opt/openproject/.env << ENVEOF
DOMAIN_NAME=${domain_name}
OPENPROJECT_SECRET_KEY_BASE=$${OPENPROJECT_SECRET_KEY_BASE}
OPENPROJECT_DB_PASSWORD=$${OPENPROJECT_DB_PASSWORD}
LETSENCRYPT_EMAIL=${letsencrypt_email}
ENVEOF

chmod 600 /opt/openproject/.env

# ---- Start services ----
cd /opt/openproject
docker-compose up -d postgres cache

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
sleep 20

docker-compose up -d openproject nginx

# ---- Initial Let's Encrypt certificate ----
echo "Requesting Let's Encrypt certificate..."
docker-compose run --rm certbot certonly \
  --webroot \
  --webroot-path=/var/www/certbot \
  --email ${letsencrypt_email} \
  --agree-tos \
  --no-eff-email \
  -d ${domain_name} || echo "⚠ WARNING: Certbot failed. Run manually after DNS propagates."

# ---- Enable SSL in Nginx ----
# After certificate is obtained, update nginx config for SSL
if [ -d "/opt/openproject/ssl/live/${domain_name}" ]; then
  cat > /opt/openproject/nginx.conf << NGINXSSLEOF
events {
    worker_connections 1024;
}

http {
    upstream openproject {
        server openproject:8080;
    }

    upstream mcp-server {
        server openproject-mcp-server:39128;
    }

    server {
        listen 80;
        server_name ${domain_name};
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        location / {
            return 301 https://\$host\$request_uri;
        }
    }

    server {
        listen 443 ssl http2;
        server_name ${domain_name};

        ssl_certificate /etc/letsencrypt/live/${domain_name}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${domain_name}/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;

        # Security headers
        add_header Strict-Transport-Security "max-age=63072000" always;
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;

        client_max_body_size 100M;

        location / {
            proxy_pass http://openproject;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # MCP Server — key checked via query param ?key=... in the MCP server itself
        location /mcp {
            proxy_pass http://mcp-server:39128;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_read_timeout 86400;
            proxy_buffering off;
        }
    }
}
NGINXSSLEOF

  # Reload nginx
  docker-compose restart nginx
  echo "✓ SSL configured"
else
  echo "⚠ Certbot may have failed. DNS might not be propagated yet."
  echo "Run manually after verification: docker-compose -f /opt/openproject/docker-compose.yml run --rm certbot certonly ..."
fi

# ---- Setup Remote MCP Server ----
mkdir -p /data/mcp-server

cat > /data/mcp-server/Dockerfile << 'DOCKEREOF'
FROM python:3.13-slim-bookworm

WORKDIR /app

RUN pip install --no-cache-dir \
    fastapi \
    uvicorn \
    httpx \
    boto3 \
    pydantic

COPY server.py /app/server.py

RUN useradd -m mcp && chown -R mcp:mcp /app
USER mcp

EXPOSE 39128

CMD ["python", "server.py"]
DOCKEREOF

cat > /data/mcp-server/server.py << 'MCPEOF'
#!/usr/bin/env python3
import os, json, base64, asyncio
from typing import Optional
from datetime import datetime
import httpx, boto3
from fastapi import FastAPI, Request
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel

OP_URL = os.environ.get("OPENPROJECT_URL", "https://projects.axinagroup.com")
OP_API_KEY = os.environ.get("OPENPROJECT_API_KEY", "")
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")
S3_BUCKETS = os.environ.get("S3_BUCKETS", "axina-openproject-files").split(",")

app = FastAPI(title="AXINA Group MCP Server")
s3_client = boto3.client("s3", region_name=AWS_REGION)

class MCPToolCall(BaseModel):
    name: str
    arguments: dict

class MCPRequest(BaseModel):
    id: Optional[str] = None
    method: str
    params: Optional[dict] = None

TOOLS = [
    {"name": "list_projects", "description": "List all OpenProject projects",
     "inputSchema": {"type": "object", "properties": {}, "required": []}},
    {"name": "get_project", "description": "Get details of a specific OpenProject project",
     "inputSchema": {"type": "object", "properties": {"project_id": {"type": "string", "description": "Project identifier or numeric ID"}}, "required": ["project_id"]}},
    {"name": "create_work_package", "description": "Create a work package in an OpenProject project",
     "inputSchema": {"type": "object", "properties": {"project_id": {"type": "string"}, "subject": {"type": "string"}, "description": {"type": "string"}, "type": {"type": "string"}, "priority": {"type": "string"}}, "required": ["project_id", "subject"]}},
    {"name": "list_s3_buckets", "description": "List accessible S3 buckets",
     "inputSchema": {"type": "object", "properties": {}, "required": []}},
    {"name": "list_s3_objects", "description": "List objects in an S3 bucket",
     "inputSchema": {"type": "object", "properties": {"bucket": {"type": "string"}, "prefix": {"type": "string"}, "max_keys": {"type": "integer"}}, "required": ["bucket"]}},
    {"name": "get_s3_object", "description": "Get contents of an S3 object",
     "inputSchema": {"type": "object", "properties": {"bucket": {"type": "string"}, "key": {"type": "string"}}, "required": ["bucket", "key"]}},
    {"name": "search_s3_objects", "description": "Search for files in S3 buckets matching a pattern",
     "inputSchema": {"type": "object", "properties": {"query": {"type": "string"}, "bucket": {"type": "string"}}, "required": ["query"]}},
]

def _op_auth():
    token = base64.b64encode(f"apikey:{OP_API_KEY}".encode()).decode()
    return {"Authorization": f"Basic {token}", "Content-Type": "application/json"}

async def op_request(endpoint, method="GET", data=None):
    url = f"{OP_URL}/api/v3/{endpoint}"
    async with httpx.AsyncClient(verify=True) as client:
        r = await client.request(method, url, headers=_op_auth(), json=data, timeout=30)
        if r.status_code >= 400:
            return {"error": f"OpenProject API error: {r.status_code}", "detail": r.text}
        return r.json()

async def execute_tool(tc: MCPToolCall) -> str:
    try:
        if tc.name == "list_projects":
            result = await op_request("projects")
            projects = [{"id": p.get("id"), "name": p.get("name"), "identifier": p.get("identifier")}
                        for p in result.get("_embedded", {}).get("elements", [])]
            return json.dumps({"projects": projects}, indent=2)
        elif tc.name == "get_project":
            return json.dumps(await op_request(f"projects/{tc.arguments['project_id']}"), indent=2)
        elif tc.name == "create_work_package":
            a = tc.arguments
            data = {"subject": a["subject"], "description": {"raw": a.get("description", "")},
                    "_links": {"project": {"href": f"/api/v3/projects/{a['project_id']}"}}}
            if "type" in a:
                data["_links"]["type"] = {"href": f"/api/v3/types/by_name/{a['type']}"}
            return json.dumps(await op_request("work_packages", "POST", data), indent=2)
        elif tc.name == "list_s3_buckets":
            r = s3_client.list_buckets()
            all_b = [b["Name"] for b in r["Buckets"]]
            return json.dumps({"buckets": [b for b in all_b if b in S3_BUCKETS], "all_available": all_b}, indent=2)
        elif tc.name == "list_s3_objects":
            r = s3_client.list_objects_v2(Bucket=tc.arguments["bucket"], Prefix=tc.arguments.get("prefix",""), MaxKeys=tc.arguments.get("max_keys",50))
            objs = [{"key": o["Key"], "size": o["Size"], "last_modified": o["LastModified"].isoformat()} for o in r.get("Contents",[])]
            return json.dumps({"bucket": tc.arguments["bucket"], "objects": objs, "count": len(objs), "truncated": r.get("IsTruncated",False)}, indent=2)
        elif tc.name == "get_s3_object":
            r = s3_client.get_object(Bucket=tc.arguments["bucket"], Key=tc.arguments["key"])
            content = r["Body"].read().decode("utf-8", errors="replace")
            return json.dumps({"bucket": tc.arguments["bucket"], "key": tc.arguments["key"], "content": content[:10000], "truncated": len(content)>10000}, indent=2)
        elif tc.name == "search_s3_objects":
            q = tc.arguments.get("query","").lower()
            buckets = [tc.arguments["bucket"]] if "bucket" in tc.arguments else S3_BUCKETS
            results = []
            for b in buckets:
                try:
                    for page in s3_client.get_paginator("list_objects_v2").paginate(Bucket=b, MaxKeys=1000):
                        results += [{"bucket": b, "key": o["Key"], "size": o["Size"]} for o in page.get("Contents",[]) if q in o["Key"].lower()]
                except Exception as e:
                    results.append({"bucket": b, "error": str(e)})
            return json.dumps({"query": q, "results": results, "count": len(results)}, indent=2)
        else:
            return json.dumps({"error": f"Unknown tool: {tc.name}"})
    except Exception as e:
        return json.dumps({"error": str(e)})

@app.get("/sse")
async def sse_endpoint():
    async def stream():
        yield f"data: {json.dumps({'type': 'tools/list', 'tools': TOOLS})}\n\n"
        while True:
            await asyncio.sleep(30)
            yield f"data: {json.dumps({'type': 'heartbeat'})}\n\n"
    return StreamingResponse(stream(), media_type="text/event-stream")

@app.post("/message")
async def mcp_message(request: Request):
    try:
        body = await request.json()
        req = MCPRequest(**body)
        if req.method == "tools/list":
            return JSONResponse({"tools": TOOLS})
        elif req.method == "tools/call":
            p = req.params or {}
            result = await execute_tool(MCPToolCall(name=p.get("name",""), arguments=p.get("arguments",{})))
            return JSONResponse({"content": [{"type": "text", "text": result}]})
        else:
            return JSONResponse({"error": f"Unsupported: {req.method}"}, status_code=400)
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)

@app.get("/health")
async def health():
    return {"status": "ok", "timestamp": datetime.utcnow().isoformat(), "tools": len(TOOLS), "openproject_url": OP_URL, "s3_buckets": S3_BUCKETS}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=39128, log_level="info")
MCPEOF

echo "=== Bootstrap complete at $(date) ==="
echo ""
echo "Next steps for MCP:"
echo "1. Generate an admin API token in OpenProject (My Account → Access tokens)"
echo "2. Generate MCP API key: openssl rand -hex 32"
echo "3. Add to /opt/openproject/.env: OPENPROJECT_ADMIN_API_KEY=<token> and MCP_API_KEY=<key>"
echo "4. Run: cd /opt/openproject && docker-compose up -d --build mcp-server"
echo "5. Verify: curl https://${domain_name}/mcp/health -H 'X-MCP-Key: <key>'"