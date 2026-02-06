# Deployment Guide - Systems Inspector Web App

Complete guide for deploying the Systems Inspector web application to Coolify at `sysinspect.skynet97.org`.

## 🎯 Overview

This guide covers:
- Coolify deployment configuration
- Environment setup
- CloudKit integration
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
- Server-to-server key generated
- See [CLOUDKIT_SETUP.md](./CLOUDKIT_SETUP.md) for details

### 3. Local Requirements
- Docker installed (for testing)
- Git repository access
- Environment variables configured

---

## 🚀 Deployment Steps

### Step 1: Prepare Repository

```bash
# Clone repository
git clone <your-repo-url>
cd "Systems Inspector/webapp"

# Verify structure
ls -la
# Should see: backend/, frontend/, Dockerfile, docker-compose.yml, docs/
```

### Step 2: Configure Environment Variables

**Production (Coolify):** Set all variables in Coolify’s UI (Application → Environment Variables). Do not rely on `.env` files in production; Coolify injects env vars at runtime.

**Local development:** Use `backend/.env` and optionally `frontend/.env` (see `backend/.env.example`).

Variables to set in Coolify:

```bash
NODE_ENV=production
PORT=3002
FRONTEND_URL=https://sysinspect.skynet97.org

# JWT Secret - CHANGE THIS! (32+ characters)
JWT_SECRET=your-super-secure-random-string-min-32-chars

# CloudKit Configuration
CLOUDKIT_CONTAINER_ID=iCloud.com.yourapp.SystemsInspector
CLOUDKIT_ENVIRONMENT=production
CLOUDKIT_API_TOKEN=your-api-token-here
CLOUDKIT_SERVER_KEY_ID=your-key-id-here
CLOUDKIT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
Your private key content here (keep line breaks)
-----END PRIVATE KEY-----"

# Optional
INSPECTOR_COMPANY=Systems Inspector
```

### Step 3: Test Locally with Docker

```bash
# Build and run
docker-compose up --build

# Test endpoints
curl http://localhost:3002/health
# Should return: {"status":"ok","timestamp":"..."}

# Access frontend
open http://localhost:5173

# Test login with your iOS app credentials
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
- Exposed ports in container: `3002` (backend), `5173` (frontend)

**Environment Variables (in Coolify UI):**

Add every variable in Coolify → Application → Environment Variables (no `.env` file in production):

```
NODE_ENV=production
PORT=3002
FRONTEND_URL=https://sysinspect.skynet97.org
JWT_SECRET=<your-secret>
CLOUDKIT_CONTAINER_ID=<your-container-id>
CLOUDKIT_ENVIRONMENT=production
CLOUDKIT_API_TOKEN=<your-token>
CLOUDKIT_SERVER_KEY_ID=<your-key-id>
CLOUDKIT_PRIVATE_KEY=<your-private-key>
```

**Troubleshooting login:** If real iOS credentials are rejected, set `DEBUG_AUTH=1` in Coolify env vars and redeploy. Check Coolify logs when attempting login; you’ll see whether the user was found and whether hash/salt are present and whether PBKDF2 verification passed (no secrets are logged).

#### 5.3 Critical: Two-Port Routing (Traefik)

The app uses two processes in one container. **You must configure two ports in Coolify** so that `/api` hits the backend and `/` hits the frontend. If everything goes to one port, `/api/customers` will return HTML and the app will break.

In Coolify → **Network** / **Routing** (or equivalent):

| Port  | Path   | Purpose                          |
|-------|--------|-----------------------------------|
| **5173** | `/`    | Frontend (React SPA)              |
| **3002** | `/api` | Backend API (Express)             |

- **Primary port:** `5173` (path `/` or empty).
- **Additional port:** `3002` with path prefix **`/api`** (Strip Prefix: NO).

Result:
- `https://sysinspect.skynet97.org/` → container port **5173** (frontend).
- `https://sysinspect.skynet97.org/api/health` → container port **3002** (backend).
- `https://sysinspect.skynet97.org/api/customers` → container port **3002** (backend).

If `/api/customers` is routed to 5173, the frontend server will return `index.html` (200 OK), the client will treat it as JSON, and you’ll see errors like `t.slice(...).map is not a function`.

**Coolify “api:3002” link:** Coolify may show a URL like `https://sysinspect.skynet97.org/api:3002`. That is a UI label (path `/api` → port 3002), not a real URL. Use `https://sysinspect.skynet97.org/` for the app and `https://sysinspect.skynet97.org/api/health` for the API; do not put `:3002` in the address bar.

#### 5.4 Configure Health Checks

**Health Check Endpoint:** `/api/health` or `/health`  
**Port:** 3002  
**Interval:** 30s  
**Timeout:** 5s  
**Retries:** 3

### Step 6: Deploy

1. Click "Deploy" button in Coolify
2. Monitor build logs
3. Wait for deployment to complete (5-10 minutes)
4. Verify health check is passing

### Step 7: Verify Deployment

```bash
# Test health endpoint
curl https://sysinspect.skynet97.org/api/health

# Test frontend
curl https://sysinspect.skynet97.org

# Test login
curl -X POST https://sysinspect.skynet97.org/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'
```

---

## 🔧 Coolify Configuration Files

### Reverse Proxy (Automatic)

Coolify automatically configures Nginx/Traefik. No manual configuration needed.

### SSL/TLS (Automatic)

Coolify automatically provisions Let's Encrypt certificates.

---

## 📊 Monitoring

### Built-in Coolify Monitoring

Coolify provides:
- **Resource usage** (CPU, Memory, Disk)
- **Application logs** (stdout/stderr)
- **Health checks** (automatic restarts)
- **Deployments history**

### Custom Monitoring

Add to your application:

```javascript
// backend/src/index.js
app.get('/metrics', (req, res) => {
  res.json({
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    cpu: process.cpuUsage(),
    timestamp: new Date().toISOString()
  });
});
```

---

## 🔄 Updates & Rollbacks

### Update Application

```bash
# Make changes
git add .
git commit -m "Update feature X"
git push origin main

# Coolify auto-deploys (if enabled)
# Or manually click "Deploy" in Coolify
```

### Rollback

1. Go to "Deployments" tab in Coolify
2. Find previous successful deployment
3. Click "Redeploy"

---

## 🐛 Troubleshooting

### Build Fails

**Check logs:**
1. Go to Coolify dashboard
2. Select your application
3. Click "Logs" → "Build Logs"

**Common issues:**
- Missing environment variables
- Dockerfile path incorrect
- Node modules not installing

**Solutions:**
```bash
# Verify Dockerfile locally
docker build -t test-build -f webapp/Dockerfile webapp/

# Check environment variables in Coolify UI
# Ensure all required vars are set
```

### Application Won't Start

**Check logs:**
```bash
# In Coolify: Logs → Application Logs
```

**Common issues:**
- Port conflicts
- Missing CloudKit credentials
- Database connection issues

**Solutions:**
1. Verify all environment variables
2. Check health endpoint manually
3. Review application logs

### CloudKit Errors

**Error: "CloudKit API Error"**

**Solutions:**
1. Verify CloudKit credentials
2. Check container ID format
3. Ensure private key is properly formatted
4. Test CloudKit connection locally

See [CLOUDKIT_SETUP.md](./CLOUDKIT_SETUP.md) for detailed troubleshooting.

### SSL Certificate Issues

**Coolify handles SSL automatically**, but if issues occur:

1. Verify domain DNS points to Coolify server
2. Check domain configuration in Coolify
3. Manually trigger certificate renewal

---

## 🔒 Security Best Practices

### 1. Environment Variables

✅ **DO:**
- Use strong, random JWT secrets (32+ characters)
- Store secrets in Coolify's encrypted storage
- Rotate secrets periodically

❌ **DON'T:**
- Commit secrets to Git
- Use weak/default secrets
- Share secrets in logs

### 2. CloudKit Security

✅ **DO:**
- Use server-to-server authentication
- Restrict CloudKit permissions
- Monitor API usage

❌ **DON'T:**
- Expose private keys
- Use client-side authentication in production
- Skip signature verification

### 3. Application Security

✅ **DO:**
- Keep dependencies updated
- Use HTTPS only
- Implement rate limiting
- Validate all inputs

❌ **DON'T:**
- Disable CORS protections
- Skip authentication checks
- Log sensitive data

---

## 📈 Performance Optimization

### 1. Frontend

```javascript
// Enable compression
// Already configured in vite.config.ts
build: {
  rollupOptions: {
    output: {
      manualChunks: {
        'react-vendor': ['react', 'react-dom'],
        'ui-vendor': ['@radix-ui/...']
      }
    }
  }
}
```

### 2. Backend

```javascript
// Enable compression (already in backend/src/index.js)
app.use(compression());

// Enable caching
app.use((req, res, next) => {
  res.set('Cache-Control', 'public, max-age=300');
  next();
});
```

### 3. Coolify

- Enable auto-scaling if needed
- Configure resource limits appropriately
- Monitor performance metrics

---

## 🔄 CI/CD Integration

### Automatic Deployments

Enable in Coolify:
1. Go to application settings
2. Enable "Auto Deploy on Git Push"
3. Configure webhook in Git repository

### Manual Deployments

Use Coolify API:

```bash
curl -X POST https://your-coolify-instance/api/deploy \
  -H "Authorization: Bearer YOUR_API_TOKEN" \
  -d '{"application_id":"your-app-id"}'
```

---

## 📱 iOS App Integration

### Update iOS App

Point your iOS app to the new web API:

```swift
// In iOS app configuration
let apiURL = "https://sysinspect.skynet97.org/api"
```

### Cross-Platform Sync

Data is automatically synced via CloudKit:
- iOS app writes to CloudKit
- Web app reads from CloudKit
- Real-time updates (with polling)

---

## 📞 Support

### Documentation
- [CloudKit Setup](./CLOUDKIT_SETUP.md)
- [API Documentation](./API.md)
- [Main README](../README.md)

### Coolify Resources
- [Coolify Docs](https://coolify.io/docs)
- [Coolify Discord](https://discord.gg/coolify)

### Issues
- Check application logs in Coolify
- Review [Troubleshooting](#-troubleshooting) section
- Contact system administrator

---

## ✅ Deployment Checklist

Before deploying to production:

- [ ] CloudKit configured and tested
- [ ] Environment variables set in Coolify
- [ ] Domain configured with SSL
- [ ] Health checks passing
- [ ] Build succeeds locally
- [ ] Authentication working
- [ ] PDF generation tested
- [ ] iOS app integration verified
- [ ] Monitoring configured
- [ ] Backups configured (if needed)

---

**Deployment Guide Version:** 1.0  
**Last Updated:** January 30, 2026  
**Domain:** sysinspect.skynet97.org  
**Platform:** Coolify 4.x

---

**🎉 You're ready to deploy!**

Follow the steps above, and your Systems Inspector web app will be live at `https://sysinspect.skynet97.org`!
