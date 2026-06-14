# Papermark Containerized Build Guide

## Build-Time Parameters Matrix

All Docker builds must compile Next.js static assets with these arguments resolved.
Any undefined host value causes `Invalid header/redirect found` and aborts the build.

| Build Argument | Purpose |
|---|---|
| `NEXT_PUBLIC_APP_BASE_HOST` | Route redirect `/` → `/dashboard` |
| `NEXT_PUBLIC_WEBHOOK_BASE_HOST` | External service proxy routing `services/:path*` |
| `NEXT_PUBLIC_API_BASE_HOST` | API host routing rules |
| `NEXT_PUBLIC_MCP_BASE_HOST` | MCP proxy host rules |
| `NEXT_PUBLIC_MCP_DOCS_URL` | MCP docs redirect URL |
| `NEXT_PUBLIC_BASE_URL` | Canonical redirect base |
| `NEXT_PUBLIC_MARKETING_URL` | Marketing domain redirects |
| `NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST` | Image optimization domain whitelist |
| `NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST_US` | US region image optimization |
| `NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST` | Advanced upload domain |
| `NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST_US` | Advanced upload US region |

## Common Commands

```bash
# Local build test
docker build \
  --build-arg NEXT_PUBLIC_APP_BASE_HOST=localhost \
  --build-arg NEXT_PUBLIC_WEBHOOK_BASE_HOST=localhost \
  --build-arg NEXT_PUBLIC_BASE_URL=http://localhost:3000 \
  -f Dockerfile -t papermark:local .

# Deploy updated Dockerfile to EC2 via S3
aws s3 cp Dockerfile s3://axina-openproject-files/deploy/papermark_dockerfile.txt
aws ssm send-command --region us-east-1 --instance-ids i-07bb8581203e52527 \
  --document-name AWS-RunShellScript \
  --parameters 'commands=["aws s3 cp s3://axina-openproject-files/deploy/papermark_dockerfile.txt /opt/papermark/Dockerfile --region us-east-1 && cd /opt/openproject && docker compose build papermark 2>&1 | tail -10"]'

# Monitor build
aws ssm get-command-invocation --region us-east-1 \
  --command-id "<ID>" --instance-id i-07bb8581203e52527 \
  --query '[Status,StandardOutputContent]' --output json
```

## Core Rules

1. **Never omit `libc6-compat`** on Alpine node images — Prisma engine binaries fail silently without it
2. **Always use `npm ci --ignore-scripts`** in the deps stage — postinstall triggers `prisma generate` before schema is copied
3. **Run `npx prisma generate` explicitly** in builder stage after `COPY . .`
4. **Supply placeholder DB URLs** in builder stage — Prisma connects during static rendering and freezes the build
5. **Node 24 required** — `package.json` specifies `engines: { node: ">=24" }`
