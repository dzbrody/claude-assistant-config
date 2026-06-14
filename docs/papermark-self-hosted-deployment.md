# Papermark Self-Hosted VDR — EC2 Deployment Reference
# Target: vdr.axinagroup.com on existing t3.large running OpenProject stack

## Prerequisites

Before starting, provision the following external accounts — Papermark's core features
depend on them regardless of self-hosting:

| Service | Purpose | Free tier |
|---------|---------|-----------|
| **Resend** | Email gating / transactional email | 3,000/mo |
| **Tinybird** | Viewer analytics | Limited free tier |
| **Upstash QStash** | Background job queue | 500/day free |

---

## Step 1: Provision the Database

Reuse the existing `openproject-postgres` container.

```bash
docker exec -it openproject-postgres psql -U openproject
```

```sql
CREATE DATABASE papermark;
CREATE USER papermark_user WITH PASSWORD 'CHANGE_ME';
GRANT ALL PRIVILEGES ON DATABASE papermark TO papermark_user;
\q
```

---

## Step 2: Build a Custom Docker Image

Papermark has no published Docker image. Build from source.

```bash
cd /opt
git clone https://github.com/papermark/papermark.git
cd papermark
```

Create `/opt/papermark/Dockerfile`:

```dockerfile
FROM node:20-alpine AS base

FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package*.json ./
RUN npm ci

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npx prisma generate
RUN npm run build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]
```

---

## Step 3: Environment Variables

Append to `/opt/openproject/.env`:

```env
# ---- Virtual Data Room (Papermark) ----
VDR_DOMAIN=vdr.axinagroup.com

# Auth
NEXTAUTH_URL=https://vdr.axinagroup.com
NEXTAUTH_SECRET=                          # openssl rand -hex 32
NEXT_PUBLIC_BASE_URL=https://vdr.axinagroup.com
NEXT_PUBLIC_MARKETING_URL=https://vdr.axinagroup.com
NEXT_PUBLIC_APP_BASE_HOST=vdr.axinagroup.com

# Database (two vars required by Prisma connection pooling)
POSTGRES_PRISMA_URL=postgresql://papermark_user:CHANGE_ME@postgres:5432/papermark
POSTGRES_PRISMA_URL_NON_POOLING=postgresql://papermark_user:CHANGE_ME@postgres:5432/papermark

# S3 Storage (instance profile NOT used — explicit keys required)
NEXT_PUBLIC_UPLOAD_TRANSPORT=s3
NEXT_PRIVATE_UPLOAD_BUCKET=axina-openproject-files
NEXT_PRIVATE_UPLOAD_REGION=us-east-1
NEXT_PRIVATE_UPLOAD_ACCESS_KEY_ID=        # IAM key with s3:PutObject / s3:GetObject on bucket
NEXT_PRIVATE_UPLOAD_SECRET_ACCESS_KEY=    # corresponding secret
NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST=axina-openproject-files.s3.us-east-1.amazonaws.com

# Email gating (Resend — not raw SMTP)
RESEND_API_KEY=                           # from resend.com

# Analytics (optional but required for viewer tracking reports)
TINYBIRD_TOKEN=                           # from tinybird.co

# Background jobs
QSTASH_TOKEN=                             # from upstash.com
QSTASH_CURRENT_SIGNING_KEY=
QSTASH_NEXT_SIGNING_KEY=

# Document password encryption
NEXT_PRIVATE_DOCUMENT_PASSWORD_KEY=       # openssl rand -hex 32

# Internal API key (used by MCP tools — generate a long random string)
PAPERMARK_API_KEY=                        # openssl rand -hex 32
```

---

## Step 4: Docker Compose Service Block

Add inside the `services:` section of `/opt/openproject/docker-compose.yml`:

```yaml
  papermark:
    build:
      context: /opt/papermark
      dockerfile: Dockerfile
    image: papermark-local:latest
    container_name: papermark-app
    restart: unless-stopped
    expose:
      - "3000"
    env_file:
      - /opt/openproject/.env
    environment:
      - NEXTAUTH_URL=https://${VDR_DOMAIN}
      - NEXT_PUBLIC_BASE_URL=https://${VDR_DOMAIN}
      - NEXT_PUBLIC_MARKETING_URL=https://${VDR_DOMAIN}
      - NEXT_PUBLIC_APP_BASE_HOST=${VDR_DOMAIN}
      - POSTGRES_PRISMA_URL=${POSTGRES_PRISMA_URL}
      - POSTGRES_PRISMA_URL_NON_POOLING=${POSTGRES_PRISMA_URL_NON_POOLING}
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
      - NEXT_PUBLIC_UPLOAD_TRANSPORT=${NEXT_PUBLIC_UPLOAD_TRANSPORT}
      - NEXT_PRIVATE_UPLOAD_BUCKET=${NEXT_PRIVATE_UPLOAD_BUCKET}
      - NEXT_PRIVATE_UPLOAD_REGION=${NEXT_PRIVATE_UPLOAD_REGION}
      - NEXT_PRIVATE_UPLOAD_ACCESS_KEY_ID=${NEXT_PRIVATE_UPLOAD_ACCESS_KEY_ID}
      - NEXT_PRIVATE_UPLOAD_SECRET_ACCESS_KEY=${NEXT_PRIVATE_UPLOAD_SECRET_ACCESS_KEY}
      - NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST=${NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST}
      - RESEND_API_KEY=${RESEND_API_KEY}
      - TINYBIRD_TOKEN=${TINYBIRD_TOKEN}
      - QSTASH_TOKEN=${QSTASH_TOKEN}
      - QSTASH_CURRENT_SIGNING_KEY=${QSTASH_CURRENT_SIGNING_KEY}
      - QSTASH_NEXT_SIGNING_KEY=${QSTASH_NEXT_SIGNING_KEY}
      - NEXT_PRIVATE_DOCUMENT_PASSWORD_KEY=${NEXT_PRIVATE_DOCUMENT_PASSWORD_KEY}
    depends_on:
      postgres:
        condition: service_healthy
```

---

## Step 5: Run Database Migrations

```bash
cd /opt/papermark
docker compose -f /opt/openproject/docker-compose.yml run --rm papermark \
  npx prisma migrate deploy
```

---

## Step 6: TLS Certificate for vdr.axinagroup.com

The existing cert covers `projects.axinagroup.com` only. Issue a new cert:

```bash
# Add the new subdomain to your existing certbot config
sudo certbot certonly --nginx \
  -d vdr.axinagroup.com \
  --email admin@axinagroup.com \
  --agree-tos --non-interactive
```

Or, if you prefer a wildcard cert to cover all subdomains going forward:

```bash
sudo certbot certonly --manual --preferred-challenges dns \
  -d "*.axinagroup.com" \
  --email admin@axinagroup.com \
  --agree-tos
```

---

## Step 7: Nginx Configuration

Add to `/opt/openproject/nginx.conf` inside the `http {}` block:

```nginx
upstream papermark {
    server papermark:3000;
}

server {
    listen 443 ssl http2;
    server_name vdr.axinagroup.com;

    ssl_certificate     /etc/letsencrypt/live/vdr.axinagroup.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/vdr.axinagroup.com/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    client_max_body_size 150M;

    location / {
        proxy_pass         http://papermark;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
    }
}

server {
    listen 80;
    server_name vdr.axinagroup.com;
    return 301 https://$host$request_uri;
}
```

---

## Step 8: Build and Launch

```bash
cd /opt/openproject

# Build the Papermark image from source
docker compose build papermark

# Bring up the new container without touching running services
docker compose up -d papermark

# Reload Nginx to pick up the new server block
docker compose exec nginx nginx -s reload
```

---

## Step 9: MCP Server Tools (server.py)

Add these two tools to `/data/mcp-server/server.py`. Note the correct API paths
(no `/api/v1/` prefix — that was a hallucination in the original instructions):

```python
import os, json, secrets, string
import httpx

VDR_BASE = os.environ.get("VDR_BASE_URL", "https://vdr.axinagroup.com")
VDR_KEY  = os.environ.get("PAPERMARK_API_KEY", "")

def _vdr_headers():
    return {"Authorization": f"Bearer {VDR_KEY}", "Content-Type": "application/json"}

@mcp.tool()
def create_secure_dataroom(name: str, description: str = "") -> str:
    """Create a private Virtual Data Room on vdr.axinagroup.com.

    Args:
        name: Data room name (e.g., 'TGI Due Diligence Q3 2026')
        description: Summary of transaction assets held in this room
    """
    with httpx.Client(timeout=10) as client:
        r = client.post(
            f"{VDR_BASE}/api/datarooms",
            headers=_vdr_headers(),
            json={"name": name, "description": description},
        )
        r.raise_for_status()
        return json.dumps(r.json(), indent=2)

@mcp.tool()
def issue_vdr_access_link(dataroom_id: str, recipient_email: str) -> str:
    """Generate a secure email-gated share link for an external partner.
    Returns the link URL and a one-time password as separate fields — deliver
    them via separate messages per the dual-channel delivery policy.

    Args:
        dataroom_id: Target data room UUID
        recipient_email: Email address used for identity gating
    """
    alphabet = string.ascii_letters + string.digits
    password = "".join(secrets.choice(alphabet) for _ in range(20))

    with httpx.Client(timeout=10) as client:
        r = client.post(
            f"{VDR_BASE}/api/links",
            headers=_vdr_headers(),
            json={
                "dataroomId": dataroom_id,
                "emailGating": True,
                "passwordEnabled": True,
                "password": password,
            },
        )
        r.raise_for_status()
        data = r.json()

    return json.dumps({
        "link_url": data.get("url"),
        "link_id": data.get("id"),
        "access_password": password,
        "delivery_note": "Send link_url and access_password in SEPARATE messages per security policy.",
    }, indent=2)
```

Restart the MCP server:

```bash
docker compose up -d --build mcp-server
```

---

## Step 10: Add PAPERMARK_API_KEY to MCP Server Environment

In your remote MCP server's compose service or `.env`:

```env
PAPERMARK_API_KEY=<value matching PAPERMARK_API_KEY on the Papermark container>
VDR_BASE_URL=https://vdr.axinagroup.com
```

---

## Verification Checklist

- [ ] `docker compose ps papermark` shows `running (healthy)`
- [ ] `curl -sk https://vdr.axinagroup.com/api/auth/session` returns JSON (not 502)
- [ ] Create a test data room via `create_secure_dataroom` tool
- [ ] Issue a test link via `issue_vdr_access_link` — confirm email gate triggers
- [ ] Viewer analytics appear in Tinybird dashboard after a document view
