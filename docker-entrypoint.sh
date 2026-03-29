#!/bin/sh
# Inject CloudKit JSON into dist/index.html from runtime env (Coolify / Docker).
# A separate /runtime-config.js file is unreliable with `serve -s` (SPA fallback can serve index.html).
set -e
node /inject-cloudkit-config.cjs
exec "$@"
