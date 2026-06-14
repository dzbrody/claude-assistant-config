---
description: Rules for modifying containerization, Docker configurations, and Next.js build-time variables.
globs: ["**/Dockerfile*", "**/docker-compose*", "**/next.config.*"]
---

# Docker Compilation & Build Safety Constraints

## Required ARGs in Builder Stage

When writing or modifying the Dockerfile, YOU MUST declare all of these in the builder stage
and map each to a matching ENV before calling `npm run build`:

```dockerfile
ARG NEXT_PUBLIC_APP_BASE_HOST=vdr.axinagroup.com
ENV NEXT_PUBLIC_APP_BASE_HOST=$NEXT_PUBLIC_APP_BASE_HOST
ARG NEXT_PUBLIC_WEBHOOK_BASE_HOST=vdr.axinagroup.com
ENV NEXT_PUBLIC_WEBHOOK_BASE_HOST=$NEXT_PUBLIC_WEBHOOK_BASE_HOST
ARG NEXT_PUBLIC_API_BASE_HOST=vdr.axinagroup.com
ENV NEXT_PUBLIC_API_BASE_HOST=$NEXT_PUBLIC_API_BASE_HOST
ARG NEXT_PUBLIC_MCP_BASE_HOST=vdr.axinagroup.com
ENV NEXT_PUBLIC_MCP_BASE_HOST=$NEXT_PUBLIC_MCP_BASE_HOST
ARG NEXT_PUBLIC_MCP_DOCS_URL=https://vdr.axinagroup.com/docs
ENV NEXT_PUBLIC_MCP_DOCS_URL=$NEXT_PUBLIC_MCP_DOCS_URL
ARG NEXT_PUBLIC_BASE_URL=https://vdr.axinagroup.com
ENV NEXT_PUBLIC_BASE_URL=$NEXT_PUBLIC_BASE_URL
ARG NEXT_PUBLIC_MARKETING_URL=https://vdr.axinagroup.com
ENV NEXT_PUBLIC_MARKETING_URL=$NEXT_PUBLIC_MARKETING_URL
ARG NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST=axina-openproject-files.s3.us-east-1.amazonaws.com
ENV NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST=$NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST
ARG NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST_US=axina-openproject-files.s3.us-east-1.amazonaws.com
ENV NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST_US=$NEXT_PRIVATE_UPLOAD_DISTRIBUTION_HOST_US
ARG NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST=axina-openproject-files.s3.us-east-1.amazonaws.com
ENV NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST=$NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST
ARG NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST_US=axina-openproject-files.s3.us-east-1.amazonaws.com
ENV NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST_US=$NEXT_PRIVATE_ADVANCED_UPLOAD_DISTRIBUTION_HOST_US
```

## Database Bypass (Prevents Build Freeze)

Next.js statically pre-renders pages at build time. Prisma will attempt a real database
connection during this phase and freeze the Docker build indefinitely.

YOU MUST supply placeholder connection strings in the builder stage:

```dockerfile
ENV DATABASE_URL="postgresql://placeholder:placeholder@localhost:5432/placeholder"
ENV POSTGRES_PRISMA_URL="postgresql://placeholder:placeholder@localhost:5432/placeholder"
ENV POSTGRES_PRISMA_URL_NON_POOLING="postgresql://placeholder:placeholder@localhost:5432/placeholder"
```

If a specific page route continues to block, add at the top of that file:
```typescript
export const dynamic = 'force-dynamic';
```

## Deps Stage Rules

- Use `npm ci --ignore-scripts` — postinstall runs `prisma generate` before schema exists
- Always install `libc6-compat` — required for Prisma engine binaries on Alpine
- Run `npx prisma generate` explicitly in builder stage AFTER `COPY . .`

## Always Set

```dockerfile
ENV NEXT_TELEMETRY_DISABLED=1
```
