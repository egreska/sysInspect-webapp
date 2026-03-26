#!/bin/sh
# Inject CloudKit settings at container start so Coolify *runtime* env vars work.
# Vite only embeds VITE_* at image build time unless these were passed as build args.
set -e
CONFIG="/app/dist/runtime-config.js"
if [ -f "$CONFIG" ]; then
  node <<'NODE'
const fs = require('fs');
const path = '/app/dist/runtime-config.js';
const c = {
  containerId: process.env.VITE_CLOUDKIT_CONTAINER_ID || '',
  apiToken: process.env.VITE_CLOUDKIT_API_TOKEN || '',
  environment: process.env.VITE_CLOUDKIT_ENVIRONMENT || '',
};
const body = 'window.__CLOUDKIT_RUNTIME_CONFIG__=' + JSON.stringify(c) + ';\n';
fs.writeFileSync(path, body, { encoding: 'utf8' });
NODE
fi
exec "$@"
