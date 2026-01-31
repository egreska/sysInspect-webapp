# Multi-stage build for production

# Stage 1: Build frontend
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend

COPY frontend/package*.json ./
RUN npm ci --only=production

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

# Install serve to serve frontend
RUN npm install -g serve pm2

# Copy backend
COPY --from=backend-builder /app/backend ./backend

# Copy frontend build
COPY --from=frontend-builder /app/frontend/dist ./frontend/dist

# Expose ports
EXPOSE 3001 5173

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD node -e "require('http').get('http://localhost:3001/health', (r) => { process.exit(r.statusCode === 200 ? 0 : 1); })"

# Start script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["start"]
