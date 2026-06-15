#!/bin/sh
set -e

echo "Starting Papermark..."

if [ -n "$DATABASE_URL" ]; then
    echo "Running database migrations..."
    max_attempts=30
    attempt=0
    # Try node_modules/.bin/prisma (present in standalone if traced), fall back to npx
    PRISMA_CMD=""
    if [ -f "node_modules/.bin/prisma" ]; then
        PRISMA_CMD="node_modules/.bin/prisma"
    elif [ -f "node_modules_build/prisma/bin/prisma" ]; then
        PRISMA_CMD="node node_modules_build/prisma/bin/prisma"
    fi

    if [ -n "$PRISMA_CMD" ]; then
        until $PRISMA_CMD db push --skip-generate || [ $attempt -eq $max_attempts ]; do
            attempt=$((attempt + 1))
            echo "  waiting for DB... attempt $attempt/$max_attempts"
            sleep 3
        done
        if [ $attempt -eq $max_attempts ]; then
            echo "ERROR: DB not reachable after $max_attempts attempts"
            exit 1
        fi
        echo "Migrations applied."
    else
        echo "Note: prisma CLI not found in image — skipping auto-migration. Run manually if needed."
    fi
fi

exec node server.js
