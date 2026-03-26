# Webapp security

Operational notes for the CloudKit JS frontend (`webapp/frontend`).

## CloudKit web API token

- The token is **embedded in the JavaScript bundle** at build time (`VITE_CLOUDKIT_API_TOKEN`). Treat it as **discoverable** by anyone who can load your deployed site.
- In [CloudKit Dashboard](https://icloud.developer.apple.com/) → **API Access** → **API Tokens**:
  - Restrict allowed **origins** to your production (and staging) HTTPS URLs only.
  - **Rotate** the token periodically and after any suspected leak; rebuild and redeploy after rotation.
- Never commit real tokens. Use `.env` / CI secrets only. The repository root `.gitignore` includes `.env`.

## Content Security Policy (CSP) and headers

The following are shipped for static hosting:

| Mechanism | Purpose |
|-----------|---------|
| `public/serve.json` | Used by [`serve`](https://github.com/vercel/serve) in the Docker image (`serve -s dist`) so Coolify/local static runs get headers. |
| `public/_headers` | Netlify-style header file copied to `dist/` for hosts that honor it. |
| `vercel.json` | Header rules when deploying the `frontend` directory to Vercel. |

If you terminate TLS or cache in front of the app (Coolify, nginx, Cloudflare), you can **duplicate** the same headers there instead of or in addition to `serve.json`.

After upgrading **CloudKit JS** or changing auth flows, test Sign in with Apple and data loads. If the browser console reports CSP violations, add only the minimum new `connect-src` / `frame-src` hosts (see Network tab) and update all three files above together.

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
