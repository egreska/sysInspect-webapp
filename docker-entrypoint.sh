#!/bin/sh
set -e

# Start backend with PM2
cd /app/backend
pm2 start src/index.js --name api --no-daemon &

# Start frontend with serve
cd /app/frontend
serve -s dist -l 5173 --no-clipboard &

# Wait for any process to exit
wait -n

# Exit with status of process that exited first
exit $?
