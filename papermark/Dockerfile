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

# All next.config.mjs host vars must be set — undefined values cause
# "Invalid header/redirect found" and abort the build
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

# Placeholder DB URLs prevent Prisma from attempting a real connection
# during Next.js static pre-rendering (causes indefinite build freeze)
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
