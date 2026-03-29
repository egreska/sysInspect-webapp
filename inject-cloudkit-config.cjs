#!/usr/bin/env node
/**
 * Replaces the JSON inside <script type="application/json" id="cloudkit-runtime-json">
 * in dist/index.html from process.env. Run at container start (see docker-entrypoint.sh).
 *
 * Accepts VITE_* names (Coolify) or shorter aliases without the prefix.
 */
const fs = require('fs');
/** Docker: /app/dist/index.html. Override for local testing. */
const indexPath = process.env.INJECT_INDEX_HTML_PATH || '/app/dist/index.html';

const containerId = String(
  process.env.VITE_CLOUDKIT_CONTAINER_ID ||
    process.env.CLOUDKIT_CONTAINER_ID ||
    ''
).trim();
const apiToken = String(
  process.env.VITE_CLOUDKIT_API_TOKEN || process.env.CLOUDKIT_API_TOKEN || ''
).trim();
const environment = String(
  process.env.VITE_CLOUDKIT_ENVIRONMENT ||
    process.env.CLOUDKIT_ENVIRONMENT ||
    ''
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
    '[inject-cloudkit-config] Warning: container id or API token is empty after inject. Set VITE_CLOUDKIT_CONTAINER_ID and VITE_CLOUDKIT_API_TOKEN (or CLOUDKIT_* aliases) on the container.'
  );
}
