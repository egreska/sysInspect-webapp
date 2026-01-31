#!/bin/sh
set -e

echo "Starting Systems Inspector Webapp..."

# Start backend with PM2 in daemon mode
echo "Starting backend API on port 3001..."
cd /app/backend
pm2 start src/index.js --name api

# Wait for backend to be ready
echo "Waiting for backend to be ready..."
sleep 3

# Test backend health
if ! wget --spider --quiet --tries=5 --timeout=2 http://localhost:3001/health; then
    echo "ERROR: Backend failed to start!"
    pm2 logs
    exit 1
fi

echo "Backend is ready!"

# Start nginx in foreground
echo "Starting nginx on port 80..."
exec nginx -g 'daemon off;'
