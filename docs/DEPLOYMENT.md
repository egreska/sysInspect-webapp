# Deployment Guide - Systems Inspector Web App

Complete guide for deploying the Systems Inspector web application to Coolify at `sysinspect.skynet97.org`.

## 🎯 Overview

This guide covers:
- Coolify deployment configuration
- Frontend-only build (CloudKit JS)
- SSL/HTTPS configuration
- Production best practices

---

## 📋 Prerequisites

### 1. Coolify Instance
- Coolify 4.x installed and running
- Access to Coolify dashboard
- Domain `sysinspect.skynet97.org` configured

### 2. CloudKit Setup
- Apple Developer Account
- CloudKit container configured
- **API Token** for web app (CloudKit Dashboard → API Access → API Tokens)
- See [CLOUDKIT_SETUP.md](./CLOUDKIT_SETUP.md) for details

### 3. Local Requirements
- Docker installed (for testing)
- Git repository access

---

## 🚀 Deployment Steps

### Step 1: Prepare Repository

```bash
git clone <your-repo-url>
cd "Systems Inspector/webapp"

# Verify structure
ls -la
# Should see: frontend/, Dockerfile, docs/
```

### Step 2: Configure CloudKit variables (runtime **or** build-time)

**Recommended (Docker / Coolify):** Set these as **runtime environment variables** on the container (names below). On each start, `docker-entrypoint.sh` runs `inject-cloudkit-config.cjs`, which **embeds** the values into `dist/index.html` inside `<script type="application/json" id="cloudkit-runtime-json">`. That avoids relying on a separate `/runtime-config.js` file, which `serve -s` can incorrectly serve as `index.html` (SPA fallback).

```bash
VITE_CLOUDKIT_CONTAINER_ID=iCloud.SysInspectDB
VITE_CLOUDKIT_API_TOKEN=your-api-token-here
VITE_CLOUDKIT_ENVIRONMENT=development   # or production — must match where your CloudKit data lives
```

**Optional build-time (Vite):** If you pass the same variables as **Docker build args** during `docker build`, they are also embedded in the JS bundle. Runtime variables **override** non-empty values when both are set.

**Local `npm run dev`:** Use `frontend/.env` or `.env.local` (Vite reads `import.meta.env`). The JSON block in `index.html` stays empty in dev.

### Step 3: Test Locally with Docker

```bash
cd webapp
docker build -t sysinspect-webapp .
docker run -p 5173:5173 \
  -e VITE_CLOUDKIT_CONTAINER_ID=iCloud.SysInspectDB \
  -e VITE_CLOUDKIT_API_TOKEN=your-token \
  -e VITE_CLOUDKIT_ENVIRONMENT=development \
  sysinspect-webapp

# Access frontend
open http://localhost:5173
```

### Step 4: Push to Repository

```bash
git add .
git commit -m "Configure for Coolify deployment"
git push origin main
```

### Step 5: Configure Coolify

#### 5.1 Create New Application

1. Log into Coolify dashboard
2. Click "New Resource" → "Application"
3. Select your Git repository
4. Branch: `main`
5. Build Pack: `Dockerfile`

#### 5.2 Configure Build Settings

**Build Configuration:**
- Dockerfile Path: `webapp/Dockerfile`
- Build Context: `webapp/`
- Exposed port: `5173` (frontend only)

**Environment variables (required):** In Coolify → **Environment Variables** (runtime), add:
- `VITE_CLOUDKIT_CONTAINER_ID` – must match iOS app (`iCloud.SysInspectDB` from entitlements)
- `VITE_CLOUDKIT_API_TOKEN` – API token from CloudKit Dashboard
- `VITE_CLOUDKIT_ENVIRONMENT` – `development` or `production` (must match your CloudKit data)

Aliases (if your host strips the `VITE_` prefix): `CLOUDKIT_CONTAINER_ID`, `CLOUDKIT_API_TOKEN`, `CLOUDKIT_ENVIRONMENT`.

**Build arguments:** Optional. Only needed if you want values baked into the bundle at build time; runtime vars are enough for the provided Dockerfile + entrypoint.

**If you still see “CloudKit not configured”:**
1. In Coolify, **do not replace** the image `ENTRYPOINT` / use a custom start command that skips `docker-entrypoint.sh` — the inject step must run before `serve`.
2. Confirm the three variables are on the **running** container (runtime), not only build-time.
3. **View page source** in the browser: you should see `id="cloudkit-runtime-json"` with non-empty `containerId` and `apiToken`. If they are empty strings, env vars are not reaching the container.
4. Redeploy using the latest `Dockerfile`, `docker-entrypoint.sh`, and `inject-cloudkit-config.cjs` from `webapp/`.

#### 5.3 Single-Port Routing

The app is frontend-only. One port serves the SPA:

| Port  | Path | Purpose              |
|-------|------|----------------------|
| **5173** | `/`  | Frontend (React SPA) |

- `https://sysinspect.skynet97.org/` → container port **5173**

#### 5.4 Configure Health Checks

**Health Check:** `http://localhost:5173/`  
**Port:** 5173  
**Interval:** 30s  
**Timeout:** 5s  
**Retries:** 3  

---

## Security headers and CloudKit token

- **Headers:** The production build copies `frontend/public/serve.json` and `_headers` into `dist/`. The Docker image runs `serve -s dist`, which applies `serve.json` response headers (`X-Content-Type-Options`, `Referrer-Policy`, etc.). **CSP is not** set here (CloudKit + Sign in with Apple need many Apple endpoints). If your reverse proxy overwrites headers, mirror these or add CSP only after **Report-Only** testing (see [SECURITY.md](./SECURITY.md)).
- **Vercel / Netlify:** Use `frontend/vercel.json` or `public/_headers` respectively when deploying there.
- **Token:** Restrict and rotate the CloudKit web API token per [SECURITY.md](./SECURITY.md).

---

## 🔄 Updates & Rollbacks

### Update Application

```bash
git add .
git commit -m "Update feature X"
git push origin main
# Coolify auto-deploys (if enabled) or manually click "Deploy"
```

### Rollback

1. Go to "Deployments" tab in Coolify
2. Find previous successful deployment
3. Click "Redeploy"

---

## 🐛 Troubleshooting

### Build Fails

- Check Coolify build logs
- Verify Dockerfile path: `webapp/Dockerfile`
- Ensure `frontend/` exists and has `package.json`

```bash
docker build -t test-build -f webapp/Dockerfile webapp/
```

### Dashboard shows no data (but data exists in CloudKit Dashboard)

**Cause:** CloudKit **Development** and **Production** are separate databases. The web app must use the same environment where your data lives.

**Fix:**
1. In [CloudKit Dashboard](https://icloud.developer.apple.com) → **Data**, check whether you're viewing **Development** or **Production**
2. Set `VITE_CLOUDKIT_ENVIRONMENT` to match:
   - Data in Development → `VITE_CLOUDKIT_ENVIRONMENT=development`
   - Data in Production → `VITE_CLOUDKIT_ENVIRONMENT=production`
3. **Redeploy** (full rebuild) – env vars are baked in at build time
4. Verify: The app footer shows "CloudKit: development" or "CloudKit: production"

**Note:** iOS debug builds typically use Development; TestFlight/App Store use Production.

---

### "CloudKit not configured" or ".then is not a function"

**Cause:** Build-time variables were not available during Docker build.

**Fix:**
1. Add `VITE_CLOUDKIT_CONTAINER_ID`, `VITE_CLOUDKIT_API_TOKEN`, `VITE_CLOUDKIT_ENVIRONMENT` in Coolify → Environment Variables
2. Ensure **Advanced** → **Inject Build Args to Dockerfile** is **Enabled**
3. **Redeploy** (full rebuild) – do not just restart the container
4. Verify variable names match exactly (no typos, correct casing)

**Test locally:**
```bash
docker build -t test --build-arg VITE_CLOUDKIT_CONTAINER_ID=iCloud.SysInspectDB --build-arg VITE_CLOUDKIT_API_TOKEN=your-token webapp/
```

See [CLOUDKIT_SETUP.md](./CLOUDKIT_SETUP.md) for API token setup.

---

## ✅ Deployment Checklist

- [ ] CloudKit API token created with **Allowed Origins** set to your domains
- [ ] Build-time env vars configured (VITE_CLOUDKIT_*)
- [ ] Domain configured with SSL
- [ ] Health checks passing
- [ ] Build succeeds locally
- [ ] Sign in with Apple working

---

**Deployment Guide Version:** 2.0 (Frontend-only)  
**Last Updated:** January 30, 2026  
**Domain:** sysinspect.skynet97.org  
**Platform:** Coolify 4.x
