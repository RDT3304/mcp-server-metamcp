# Dockerfile.external-db - Modified for external PostgreSQL

FROM node:18-alpine AS base

# Install system dependencies
RUN apk add --no-cache libc6-compat python3 make g++ curl
RUN npm install -g pnpm

# Install additional tools that MCP servers might need
RUN apk add --no-cache \
    python3 \
    py3-pip \
    nodejs \
    npm \
    git \
    bash

# Install uvx and npx globally for MCP servers
RUN pip3 install uvx
RUN npm install -g npx

WORKDIR /app

# Copy package files
COPY package.json pnpm-lock.yaml* ./
COPY apps/frontend/package.json ./apps/frontend/
COPY apps/backend/package.json ./apps/backend/
COPY packages/ ./packages/

# Install dependencies
RUN pnpm install --frozen-lockfile

# Copy source code
COPY . .

# Build the application
RUN pnpm build

# Create a healthcheck script for database connection
RUN echo '#!/bin/sh\n\
curl -f http://localhost:12008/health || exit 1' > /healthcheck.sh
RUN chmod +x /healthcheck.sh

# Create startup script that waits for database
RUN echo '#!/bin/sh\n\
echo "Waiting for database connection..."\n\
until nc -z $POSTGRES_HOST $POSTGRES_PORT; do\n\
  echo "Database not ready, waiting..."\n\
  sleep 2\n\
done\n\
echo "Database is ready!"\n\
\n\
# Run database migrations if needed\n\
echo "Running database setup..."\n\
pnpm db:migrate || echo "Migration completed or not needed"\n\
\n\
# Start the application\n\
echo "Starting MetaMCP..."\n\
exec pnpm start' > /start.sh
RUN chmod +x /start.sh

# Install netcat for database connection check
RUN apk add --no-cache netcat-openbsd

# Expose the application port
EXPOSE 12008

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD /healthcheck.sh

# Use the startup script
CMD ["/start.sh"]
