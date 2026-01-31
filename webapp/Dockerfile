# Multi-stage build for production

# Stage 1: Build frontend
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend

# Install ALL dependencies (including dev) needed for building
COPY frontend/package*.json ./
RUN npm ci

COPY frontend/ ./
RUN npm run build

# Stage 2: Build backend
FROM node:20-alpine AS backend-builder

WORKDIR /app/backend

COPY backend/package*.json ./
RUN npm ci --only=production

COPY backend/ ./

# Stage 3: Production image
FROM node:20-alpine

WORKDIR /app

# Install nginx and pm2
RUN apk add --no-cache nginx && \
    npm install -g pm2

# Copy backend
COPY --from=backend-builder /app/backend ./backend

# Copy frontend build
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Create nginx directories
RUN mkdir -p /var/log/nginx /var/lib/nginx/tmp /run/nginx && \
    chown -R node:node /var/log/nginx /var/lib/nginx /run/nginx /app

# Expose single port for nginx
EXPOSE 80

# Health check through nginx
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:80/health || exit 1

# Start script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["start"]
