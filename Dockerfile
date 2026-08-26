# syntax=docker/dockerfile:1.4
# Frontend-only build (CloudKit JS - no backend)
#
# Build context options (set Coolify "Base Directory" / Docker context accordingly):
#   A) Context = `webapp` (recommended): default — no extra build args.
#   B) Context = repository root: pass build arg: SRC_PREFIX=webapp/
#
ARG SRC_PREFIX=

FROM node:20-alpine AS frontend-builder
ARG SRC_PREFIX

WORKDIR /app/frontend

ARG VITE_CLOUDKIT_CONTAINER_ID
ARG VITE_CLOUDKIT_API_TOKEN
ARG VITE_CLOUDKIT_ENVIRONMENT=production
ENV VITE_CLOUDKIT_CONTAINER_ID=$VITE_CLOUDKIT_CONTAINER_ID \
    VITE_CLOUDKIT_API_TOKEN=$VITE_CLOUDKIT_API_TOKEN \
    VITE_CLOUDKIT_ENVIRONMENT=$VITE_CLOUDKIT_ENVIRONMENT

COPY ${SRC_PREFIX}frontend/package*.json ./
RUN npm ci

COPY ${SRC_PREFIX}frontend/ ./
RUN npm run build

FROM node:20-alpine
ARG SRC_PREFIX

WORKDIR /app

RUN npm install -g serve

COPY --from=frontend-builder /app/frontend/dist ./dist

# Inlined so `docker build` never depends on a second file that might be missing from git.
COPY <<'EOF' /inject-cloudkit-config.cjs
const fs = require('fs');
const indexPath = process.env.INJECT_INDEX_HTML_PATH || '/app/dist/index.html';
const containerId = String(
  process.env.VITE_CLOUDKIT_CONTAINER_ID || process.env.CLOUDKIT_CONTAINER_ID || ''
).trim();
const apiToken = String(
  process.env.VITE_CLOUDKIT_API_TOKEN || process.env.CLOUDKIT_API_TOKEN || ''
).trim();
const environment = String(
  process.env.VITE_CLOUDKIT_ENVIRONMENT || process.env.CLOUDKIT_ENVIRONMENT || ''
).trim();
const cfg = { containerId, apiToken, environment };
const json = JSON.stringify(cfg).replace(/</g, '\\u003c');
let html = fs.readFileSync(indexPath, 'utf8');
const re =
  /(<script\s+type="application\/json"\s+id="cloudkit-runtime-json"\s*>)([\s\S]*?)(<\/script>)/i;
if (!re.test(html)) {
  console.error(
    '[inject-cloudkit-config] Missing <script type="application/json" id="cloudkit-runtime-json"> in index.html'
  );
  process.exit(1);
}
html = html.replace(re, `$1${json}$3`);
fs.writeFileSync(indexPath, html, 'utf8');
if (!containerId || !apiToken) {
  console.warn(
    '[inject-cloudkit-config] Warning: container id or API token is empty. Set VITE_CLOUDKIT_* on the container.'
  );
}
EOF

COPY ${SRC_PREFIX}docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh /inject-cloudkit-config.cjs

RUN apk add --no-cache wget

EXPOSE 5173

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:5173/ || exit 1

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["serve", "-s", "dist", "-l", "5173", "--no-clipboard"]
