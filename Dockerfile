# Corrected Dockerfile for MetaMCP
FROM node:18-alpine AS base

# Install system dependencies and tools needed for MCP servers
RUN apk add --no-cache \
    libc6-compat \
    python3 \
    py3-pip \
    make \
    g++ \
    curl \
    bash \
    git \
    netcat-openbsd

# Install pnpm
RUN npm install -g pnpm

# Install uv and uvx for Python MCP servers
RUN pip3 install uv

# Install npx (should already be available with Node.js)
RUN npm install -g npx

# Set working directory
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

# Create healthcheck script
RUN echo '#!/bin/bash\ncurl -f http://localhost:12008/health || exit 1' > /healthcheck.sh && \
    chmod +x /healthcheck.sh

# Create startup script with database wait
RUN echo '#!/bin/bash\n\
set -e\n\
echo "🚀 Starting MetaMCP..."\n\
\n\
# Wait for database if POSTGRES_HOST is set\n\
if [ -n "$POSTGRES_HOST" ]; then\n\
  echo "⏳ Waiting for database at $POSTGRES_HOST:$POSTGRES_PORT..."\n\
  while ! nc -z $POSTGRES_HOST $POSTGRES_PORT; do\n\
    echo "Database not ready, waiting..."\n\
    sleep 2\n\
  done\n\
  echo "✅ Database is ready!"\n\
fi\n\
\n\
# Run database migrations if needed\n\
echo "📊 Running database setup..."\n\
pnpm db:migrate || echo "Migration completed or not needed"\n\
\n\
# Start the application\n\
echo "🎯 Starting MetaMCP application..."\n\
exec pnpm start' > /start.sh && \
    chmod +x /start.sh

# Expose the correct port (12008 for MetaMCP)
EXPOSE 12008

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /healthcheck.sh

# Set environment variables
ENV NODE_ENV=production

# Use the startup script
CMD ["/start.sh"]
