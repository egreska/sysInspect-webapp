#!/bin/sh
set -e

echo "Starting Systems Inspector Webapp..."

# Start backend with PM2 in daemon mode
echo "Starting backend API on port 3002..."
cd /app/backend
pm2 start src/index.js --name api

# Wait for backend to be ready
echo "Waiting for backend to be ready..."
sleep 3

# Test backend health
if ! wget --spider --quiet --tries=5 --timeout=2 http://localhost:3002/health; then
    echo "ERROR: Backend failed to start!"
    pm2 logs
    exit 1
fi

echo "Backend is ready!"

# Start frontend with serve on port 5173 (foreground)
echo "Starting frontend on port 5173..."
cd /app/frontend/dist
exec serve -s . -l 5173 --no-clipboard
