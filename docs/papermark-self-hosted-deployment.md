# Papermark Self-Hosted VDR — EC2 Deployment Reference
# Target: vdr.axinagroup.com on t4g.xlarge (aarch64 Graviton2)
# Status: Build pipeline validated — live at vdr.axinagroup.com

## Infrastructure State

| Item | Value |
|------|-------|
| EC2 instance | `i-07bb8581203e52527` t4g.xlarge aarch64 |
| Domain | `vdr.axinagroup.com` → `44.195.198.18` (Route53 A record live) |
| TLS cert | `/etc/letsencrypt/live/vdr.axinagroup.com/` — expires 2026-09-12 |
| Database | `papermark` DB + `papermark_user` on existing `openproject-postgres` |
| S3 IAM user | `papermark-vdr-s3` — scoped to `axina-openproject-files/papermark/*` |
| S3 key ID | `AKIAQE3ROVJ3NYPLBHPK` |
| Source | `/opt/papermark/` (cloned from `github.com/papermark/papermark`) |

---

## Prerequisites

Sign up and obtain API keys for these required external services before launching:

| Service | Purpose | Free tier |
|---------|---------|-----------|
| **Resend** | Email gating / transactional email | 3,000/mo |
| **Tinybird** | Viewer analytics | Limited free tier |
| **Upstash QStash** | Background job queue | 500/day free |

---

## Step 1: Database (already provisioned)

Database and user already created. Password is in `/opt/openproject/.env` as
`POSTGRES_PRISMA_URL`. To re-provision if needed:

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

## Step 2: Dockerfile (aarch64 validated — v6)

Build constraints discovered during live compile iterations on Graviton2:

1. **Node 24 required** — `package.json` specifies `engines: { node: ">=24" }`
2. **`npm ci --ignore-scripts`** — postinstall triggers `prisma generate` before schema is copied; must skip and run explicitly
3. **All `next.config.mjs` host vars must be ARGs** — Next.js validates route `has` objects at build time; any undefined host env var causes `Invalid header/redirect found` and aborts the build
4. **Placeholder DB URLs required** — Next.js statically pre-renders pages; Prisma attempts a real DB connection during this phase and freezes the build indefinitely

`/opt/papermark/Dockerfile`:

```dockerfile
FROM node:24-alpine AS base

FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package*.json ./
RUN npm ci --ignore-scripts

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
ARG NEXT_PUBLIC_APP_BASE_HOST=vdr.axinagroup.com
ENV NEXT_PUBLIC_APP_BASE_HOST=$NEXT_PUBLIC_APP_BASE_HOST
ARG NEXT_PUBLIC_BASE_URL=https://vdr.axinagroup.com
ENV NEXT_PUBLIC_BASE_URL=$NEXT_PUBLIC_BASE_URL
ARG NEXT_PUBLIC_MARKETING_URL=https://vdr.axinagroup.com
ENV NEXT_PUBLIC_MARKETING_URL=$NEXT_PUBLIC_MARKETING_URL
ARG NEXT_PUBLIC_WEBHOOK_BASE_HOST=vdr.axinagroup.com
ENV NEXT_PUBLIC_WEBHOOK_BASE_HOST=$NEXT_PUBLIC_WEBHOOK_BASE_HOST
ARG NEXT_PUBLIC_API_BASE_HOST=vdr.axinagroup.com
ENV NEXT_PUBLIC_API_BASE_HOST=$NEXT_PUBLIC_API_BASE_HOST
ARG NEXT_PUBLIC_MCP_BASE_HOST=vdr.axinagroup.com
ENV NEXT_PUBLIC_MCP_BASE_HOST=$NEXT_PUBLIC_MCP_BASE_HOST
ARG NEXT_PUBLIC_MCP_DOCS_URL=https://vdr.axinagroup.com/docs
ENV NEXT_PUBLIC_MCP_DOCS_URL=$NEXT_PUBLIC_MCP_DOCS_URL
ARG NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST=axina-openproject-files.s3.us-east-1.amazonaws.com
ENV NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST=$NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST
ARG NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST_US=axina-openproject-files.s3.us-east-1.amazonaws.com
ENV NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST_US=$NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST_US
ARG NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST=axina-openproject-files.s3.us-east-1.amazonaws.com
ENV NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST=$NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST
ARG NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST_US=axina-openproject-files.s3.us-east-1.amazonaws.com
ENV NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST_US=$NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST_US

# Prevents Prisma from attempting a real DB connection during static pre-rendering
ENV DATABASE_URL="postgresql://placeholder:placeholder@localhost:5432/placeholder"
ENV POSTGRES_PRISMA_URL="postgresql://placeholder:placeholder@localhost:5432/placeholder"
ENV POSTGRES_PRISMA_URL_NON_POOLING="postgresql://placeholder:placeholder@localhost:5432/placeholder"

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
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone/server.js ./server.js
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT=3000
CMD ["node", "server.js"]
```

---

## Step 3: Environment Variables

All Papermark vars are appended to `/opt/openproject/.env`. Keys already set:
- `VDR_DOMAIN`, `NEXTAUTH_URL`, `NEXT_PUBLIC_*`, `POSTGRES_PRISMA_URL*`
- `NEXT_PUBLIC_UPLOAD_TRANSPORT`, `NEXT_PRIVATE_UPLOAD_*`
- `NEXT_PRIVATE_DOCUMENT_PASSWORD_KEY`, `PAPERMARK_API_KEY`

**Still required — add after obtaining from external services:**

```env
RESEND_API_KEY=           # resend.com
TINYBIRD_TOKEN=           # tinybird.co
QSTASH_TOKEN=             # upstash.com
QSTASH_CURRENT_SIGNING_KEY=
QSTASH_NEXT_SIGNING_KEY=
```

---

## Step 4: Docker Compose Service Block

Already injected into `/opt/openproject/docker-compose.yml`:

```yaml
  papermark:
    build:
      context: /opt/papermark
      dockerfile: Dockerfile
      args:
        - NEXT_PUBLIC_WEBHOOK_BASE_HOST=vdr.axinagroup.com
        - NEXT_PUBLIC_APP_BASE_HOST=vdr.axinagroup.com
        - NEXT_PUBLIC_BASE_URL=https://vdr.axinagroup.com
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

## Step 5: Nginx (already configured)

`vdr.axinagroup.com` upstream and SSL server block already added to
`/opt/openproject/nginx.conf`. SSL cert is live.

---

## Step 6: Build, Migrate, Launch

```bash
cd /opt/openproject

# Build (uses cached layers after first successful run)
docker compose build papermark

# Run Prisma migrations
docker compose run --rm papermark npx prisma migrate deploy

# Start
docker compose up -d papermark

# Reload nginx (once papermark-app container is running)
docker compose exec nginx nginx -s reload
```

---

## Step 7: MCP Integration (server.py)

VDR tools are in `mcp-servers/openproject-mcp/src/tools/vdr.py` (3 tools):
- `create_secure_dataroom(name, description)`
- `issue_vdr_access_link(dataroom_id, recipient_email)` — returns link + password separately
- `list_datarooms()`

Reads `VDR_BASE_URL` and `PAPERMARK_API_KEY` from container env.

To deploy updated MCP server with VDR tools:

```bash
cd /opt/openproject
# Source already at /data/mcp-server/ — rebuild to pick up vdr.py
docker compose build mcp-server
docker compose up -d --no-deps mcp-server
```

---

## IAM — papermark-vdr-s3

Scoped IAM user created 2026-06-14. Policy: `s3:PutObject`, `s3:GetObject`,
`s3:DeleteObject`, `s3:GetObjectAttributes` on `axina-openproject-files/papermark/*` only.
Key ID: `AKIAQE3ROVJ3NYPLBHPK`. Secret stored in `/opt/openproject/.env`.
