# syntax=docker/dockerfile:1

ARG NODE_VERSION=20

# ============================================================================
# Stage 1: Dependencies
# ============================================================================
FROM node:${NODE_VERSION}-alpine AS deps

RUN apk add --no-cache libc6-compat openssl
WORKDIR /app

COPY package.json package-lock.json* ./
COPY prisma ./prisma

# npm install fallback: ci fails if lockfile is out of sync on self-host forks
RUN npm install --ignore-scripts || npm ci --ignore-scripts || true

# ============================================================================
# Stage 2: Builder
# ============================================================================
FROM node:${NODE_VERSION}-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Replace next.config.mjs with Docker-safe version BEFORE build
COPY next.config.docker.mjs ./next.config.mjs

ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=4096"

# Build-time host/URL args (baked into static assets)
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

# Placeholder DB URLs — Prisma must not connect during static rendering
ENV DATABASE_URL="postgresql://placeholder:placeholder@localhost:5432/placeholder"
ENV POSTGRES_PRISMA_URL="postgresql://placeholder:placeholder@localhost:5432/placeholder"
ENV POSTGRES_PRISMA_URL_NON_POOLING="postgresql://placeholder:placeholder@localhost:5432/placeholder"

# Placeholder keys for optional integrations that are imported at module load
ENV OPENAI_API_KEY=sk-placeholder
ENV HANKO_API_KEY=placeholder
ENV NEXT_PUBLIC_HANKO_TENANT_ID=placeholder
ENV SLACK_CLIENT_ID=placeholder
ENV SLACK_CLIENT_SECRET=placeholder

RUN npx prisma generate
RUN npm run build

# ============================================================================
# Stage 3: Production Runtime
# ============================================================================
FROM node:${NODE_VERSION}-alpine AS runner

RUN apk add --no-cache libc6-compat openssl curl bash

WORKDIR /app

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 nextjs

ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

# Standalone output: server.js + its own node_modules snapshot
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/prisma ./prisma
# Copy prisma CLI so entrypoint can run migrations at startup
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/.bin/prisma ./node_modules/.bin/prisma
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/prisma ./node_modules/prisma
COPY --from=builder --chown=nextjs:nodejs /app/node_modules/@prisma ./node_modules/@prisma

COPY --chmod=755 docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chown nextjs:nodejs /app/docker-entrypoint.sh

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/api/health || exit 1

ENTRYPOINT ["/app/docker-entrypoint.sh"]
