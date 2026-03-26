# Webapp security

Operational notes for the CloudKit JS frontend (`webapp/frontend`).

## CloudKit web API token

- The token is **embedded in the JavaScript bundle** at build time (`VITE_CLOUDKIT_API_TOKEN`). Treat it as **discoverable** by anyone who can load your deployed site.
- In [CloudKit Dashboard](https://icloud.developer.apple.com/) → **API Access** → **API Tokens**:
  - Restrict allowed **origins** to your production (and staging) HTTPS URLs only.
  - **Rotate** the token periodically and after any suspected leak; rebuild and redeploy after rotation.
- Never commit real tokens. Use `.env` / CI secrets only. The repository root `.gitignore` includes `.env`.

## HTTP security headers (no CSP on `serve`)

The following are shipped for static hosting (`serve.json`, `_headers`, `vercel.json`):

- `X-Content-Type-Options: nosniff`
- `Referrer-Policy: strict-origin-when-cross-origin`
- `Permissions-Policy` (camera/mic/geo disabled)
- `X-Frame-Options: DENY`

**Content-Security-Policy is not set** in those files. A strict CSP applied by `serve` blocked **CloudKit JS** and **Sign in with Apple** (extra script/connect/form targets and Apple endpoints). If you want CSP, add it at your **reverse proxy** (Coolify, nginx, Cloudflare) and start with **`Content-Security-Policy-Report-Only`**, watch reports for blocked URLs, then tighten and switch to enforcing.

## Production logging

Verbose CloudKit logging uses `src/utils/logger.ts`: `debug` / `warn` run only when `import.meta.env.DEV` is true. Production builds log shortened `error` lines without attaching full error objects to the console.

## iCloud asset URLs

Photo `downloadURL` values behave like **bearer links**. Do not log full URLs in production; avoid sharing screenshots that expose them.

## Incident checklist (token compromise)

1. Create a **new** API token in CloudKit Dashboard with correct origin restrictions.
2. Update the deployment secret / build env (`VITE_CLOUDKIT_API_TOKEN`).
3. Rebuild and redeploy the frontend.
4. Revoke or delete the old token in the dashboard.
5. Review CloudKit usage metrics if available; consider notifying users per your policy.
