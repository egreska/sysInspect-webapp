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

### Step 2: Configure Environment Variables

**Production (Coolify):** Set variables in Coolify’s UI (Application → Environment Variables).

**Build-time (Vite):** These are baked into the frontend at build time. Set in Coolify as build args or in a build script:

```bash
VITE_CLOUDKIT_CONTAINER_ID=iCloud.com.yourapp.SystemsInspector
VITE_CLOUDKIT_API_TOKEN=your-api-token-here
VITE_CLOUDKIT_ENVIRONMENT=production
```

**Note:** For Vite, env vars must be available during `npm run build`. If Coolify doesn’t pass them, use a build script that creates `.env.production` from Coolify’s env vars before running the build.

### Step 3: Test Locally with Docker

```bash
cd webapp
docker build -t sysinspect-webapp .
docker run -p 5173:5173 sysinspect-webapp

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

**Build Arguments:** In Coolify → Build Arguments, add:
- `VITE_CLOUDKIT_CONTAINER_ID` – your CloudKit container ID
- `VITE_CLOUDKIT_API_TOKEN` – API token from CloudKit Dashboard
- `VITE_CLOUDKIT_ENVIRONMENT` – `production` or `development`

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

### CloudKit Errors in Browser

- Verify `VITE_CLOUDKIT_*` env vars are set at build time
- Check API token in CloudKit Dashboard
- Ensure Sign in with Apple is enabled for the web app

See [CLOUDKIT_SETUP.md](./CLOUDKIT_SETUP.md) for details.

---

## ✅ Deployment Checklist

- [ ] CloudKit API token created
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
