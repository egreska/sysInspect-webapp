# 🚀 Coolify + Traefik Configuration

**Architecture:** Two-port with Traefik routing (no Nginx needed)  
**Status:** ✅ **PRODUCTION READY**

---

## 🏗️ **Architecture**

```
User Browser
     ↓
Cloudflare Tunnel (sysinspect.skynet97.org)
     ↓
Coolify Server
     ↓
Traefik (Built-in Reverse Proxy)
     ├─ / → Container Port 5173 (Frontend)
     └─ /api → Container Port 3001 (Backend)
     ↓
Docker Container
     ├─ Frontend (serve on port 5173)
     └─ Backend (Express on port 3002)
```

---

## ✅ **Why No Nginx?**

You already have:
- ✅ **Traefik** - Built into Coolify for routing
- ✅ **Cloudflared** - Cloudflare Tunnel for external access
- ✅ **Cloudflare** - CDN, SSL, DDoS protection

Adding Nginx would be **redundant** - Traefik handles all routing perfectly!

---

## 🔧 **Coolify Configuration**

### **Method 1: Coolify UI (Recommended)**

#### **1. Go to your application → Routing**

#### **2. Configure Primary Port (Frontend):**
```
Primary Port: 5173
```

#### **3. Add Additional Port (Backend):**
```
Port: 3002
Path Prefix: /api
Strip Prefix: false
```

This tells Traefik:
- Route `https://sysinspect.skynet97.org/` → Port 5173 (frontend)
- Route `https://sysinspect.skynet97.org/api` → Port 3002 (backend)

---

### **Method 2: Docker Labels (Alternative)**

If Coolify doesn't have UI routing options, add these labels in **Advanced → Docker Labels**:

```yaml
# Frontend routing
traefik.http.routers.frontend.rule=Host(`sysinspect.skynet97.org`)
traefik.http.routers.frontend.service=frontend
traefik.http.services.frontend.loadbalancer.server.port=5173
traefik.http.routers.frontend.priority=1

# Backend routing (higher priority)
traefik.http.routers.backend.rule=Host(`sysinspect.skynet97.org`) && PathPrefix(`/api`)
traefik.http.routers.backend.service=backend
traefik.http.services.backend.loadbalancer.server.port=3002
traefik.http.routers.backend.priority=10
```

**Priority matters!** Backend has higher priority (10) so `/api` routes are checked first.

---

## 📋 **Complete Coolify Configuration**

### **Build Settings:**
```
Build Pack: Dockerfile
Dockerfile Path: webapp/Dockerfile
Build Context: webapp/
Branch: main
```

### **Network Settings:**
```
Primary Port: 5173 (Frontend)

Additional Ports:
  Port: 3002
  Path: /api
```

### **Runtime Settings:**
```
GPU Support: DISABLED
Runtime: Default (runc)
```

### **Environment Variables:**
```bash
NODE_ENV=production
PORT=3002
FRONTEND_URL=https://sysinspect.skynet97.org
JWT_SECRET=<your-32-char-secret>

CLOUDKIT_CONTAINER_ID=<from-xcode>
CLOUDKIT_ENVIRONMENT=production
CLOUDKIT_API_TOKEN=<from-cloudkit-dashboard>
CLOUDKIT_SERVER_KEY_ID=<from-cloudkit-dashboard>
CLOUDKIT_PRIVATE_KEY=<from-cloudkit-dashboard>
```

### **Domain:**
```
Domain: sysinspect.skynet97.org
Cloudflare Tunnel: Enabled
SSL: Automatic via Cloudflare
```

---

## 🧪 **Testing**

After deployment:

### **1. Frontend (via Traefik → Port 5173)**
```bash
curl https://sysinspect.skynet97.org/
# Should return HTML with React app
```

### **2. Backend API (via Traefik → Port 3001)**
```bash
curl https://sysinspect.skynet97.org/api/health
# Should return {"status":"ok","timestamp":"..."}
```

### **3. Login**
```bash
curl -X POST https://sysinspect.skynet97.org/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}'
# Should return JWT token
```

---

## 🎯 **How Traefik Routes Requests**

### **Frontend Request:**
```
1. User: https://sysinspect.skynet97.org/
2. Cloudflare Tunnel → Coolify
3. Traefik: Match Host + No /api prefix
4. Route to: Container Port 5173
5. Serve: React app (index.html)
```

### **API Request:**
```
1. User: https://sysinspect.skynet97.org/api/health
2. Cloudflare Tunnel → Coolify
3. Traefik: Match Host + /api prefix
4. Route to: Container Port 3002
5. Backend: Express handles /api/health
```

---

## 📦 **Container Ports**

The container exposes **two ports**:

```
Port 5173: Frontend (serve)
  - Serves React build from /app/frontend/dist
  - Static files only
  - No server-side logic

Port 3002: Backend (Node.js/Express)
  - RESTful API
  - CloudKit integration
  - JWT authentication
  - PDF generation
```

**Traefik** (in Coolify) handles routing based on URL path.

---

## 🔧 **Troubleshooting**

### **Issue: 404 on root URL**
**Cause:** Primary port not set in Coolify  
**Fix:** Set Primary Port to `5173`

### **Issue: 404 on /api requests**
**Cause:** Backend port not configured  
**Fix:** Add port `3001` with path prefix `/api`

### **Issue: CORS errors**
**Cause:** FRONTEND_URL environment variable incorrect  
**Fix:** Ensure `FRONTEND_URL=https://sysinspect.skynet97.org`

### **Issue: Can't connect to backend**
**Cause:** Backend crashed or not starting  
**Fix:** Check container logs for errors (check all env vars set)

---

## 📊 **Performance & Security**

### **Performance:**
- ✅ **Traefik** handles load balancing
- ✅ **Cloudflare** provides CDN and caching
- ✅ **Static files** served by `serve` (fast)
- ✅ **Gzip** compression via Traefik
- ✅ **HTTP/2** support

### **Security:**
- ✅ **Cloudflare** - SSL/TLS, DDoS protection
- ✅ **Cloudflared** - Hidden origin server
- ✅ **Traefik** - Reverse proxy, rate limiting
- ✅ **Express** - CORS, Helmet, rate limiting
- ✅ **JWT** - Secure authentication
- ✅ **CloudKit** - Ownership verification

**Multiple layers of security!**

---

## 🚀 **Deploy Steps**

### **1. Push Changes**
```bash
git push origin main
```

### **2. In Coolify → Network/Routing:**

**Configure Ports:**
- **Primary Port:** `5173`
- **Additional Port:** `3001` with path `/api`

**Or in Advanced → Docker Labels:**
```yaml
traefik.http.routers.app-api.rule=Host(`sysinspect.skynet97.org`) && PathPrefix(`/api`)
traefik.http.routers.app-api.service=app-api
traefik.http.services.app-api.loadbalancer.server.port=3001
traefik.http.routers.app-api.priority=10

traefik.http.routers.app-web.rule=Host(`sysinspect.skynet97.org`)
traefik.http.routers.app-web.service=app-web
traefik.http.services.app-web.loadbalancer.server.port=5173
traefik.http.routers.app-web.priority=1
```

### **3. Deploy!**

Click "Deploy" button.

---

## ✅ **Expected Results**

```
✅ Build completes (5-10 minutes)
✅ Container starts
✅ Backend starts on port 3001
✅ Frontend starts on port 5173
✅ Traefik routes requests:
   - / → Port 5173 (frontend)
   - /api → Port 3001 (backend)
✅ Health check passes
✅ Site accessible at https://sysinspect.skynet97.org
```

---

## 🎉 **Summary**

```
╔═══════════════════════════════════════════╗
║                                           ║
║   ✅ TRAEFIK ARCHITECTURE READY! ✅      ║
║                                           ║
║  Nginx:              ❌ Removed          ║
║  Traefik:            ✅ Built-in         ║
║  Cloudflared:        ✅ Active           ║
║  Two-port setup:     ✅ Configured       ║
║                                           ║
║  Frontend Port:      5173                ║
║  Backend Port:       3001                ║
║  Traefik Routing:    Path-based          ║
║                                           ║
║  Status:             READY TO DEPLOY     ║
║                                           ║
╚═══════════════════════════════════════════╝
```

---

**No Nginx needed - Traefik does all the work!** 🚀
