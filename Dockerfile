# Frontend-only build (CloudKit JS - no backend)
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend

# Build-time CloudKit config (pass as build args in Coolify)
ARG VITE_CLOUDKIT_CONTAINER_ID
ARG VITE_CLOUDKIT_API_TOKEN
ARG VITE_CLOUDKIT_ENVIRONMENT=production
ENV VITE_CLOUDKIT_CONTAINER_ID=$VITE_CLOUDKIT_CONTAINER_ID \
    VITE_CLOUDKIT_API_TOKEN=$VITE_CLOUDKIT_API_TOKEN \
    VITE_CLOUDKIT_ENVIRONMENT=$VITE_CLOUDKIT_ENVIRONMENT

COPY frontend/package*.json ./
RUN npm ci

COPY frontend/ ./
RUN npm run build

# Production image - serve static frontend
FROM node:20-alpine

WORKDIR /app

RUN npm install -g serve

COPY --from=frontend-builder /app/frontend/dist ./dist

EXPOSE 5173

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:5173/ || exit 1

CMD ["serve", "-s", "dist", "-l", "5173", "--no-clipboard"]
