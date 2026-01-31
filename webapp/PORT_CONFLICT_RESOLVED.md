# ✅ Port Conflict Resolved!

**Issue:** Port 3001 already in use by Supabase  
**Solution:** Changed backend to use port **3002**  
**Status:** ✅ **READY TO DEPLOY**

---

## 🔧 **The Problem**

Your Coolify server already has Supabase running on port 3001, causing a port conflict:

```
Error: Backend couldn't start
Cause: Port 3001 already bound to Supabase
Result: Health check fails, deployment fails
```

---

## ✅ **The Solution**

Changed the webapp backend from port **3001** to port **3002**:

### **Files Updated:**
- `backend/src/index.js` - Default port changed to 3002
- `Dockerfile` - EXPOSE 3002, health check on 3002
- `docker-entrypoint.sh` - Start and test on 3002
- `backend/.env.example` - PORT=3002
- All documentation updated

---

## 🚀 **Coolify Configuration (UPDATED)**

### **Port Configuration:**

**In Coolify → Network/Routing:**
```
Primary Port: 5173 (Frontend)

Additional Port: 3002 ← Changed from 3001!
Path Prefix: /api
Strip Prefix: NO
```

**Or in Docker Labels:**
```yaml
traefik.http.routers.app-api.rule=Host(`sysinspect.skynet97.org`) && PathPrefix(`/api`)
traefik.http.routers.app-api.service=app-api
traefik.http.services.app-api.loadbalancer.server.port=3002
traefik.http.routers.app-api.priority=10

traefik.http.routers.app-web.rule=Host(`sysinspect.skynet97.org`)
traefik.http.routers.app-web.service=app-web
traefik.http.services.app-web.loadbalancer.server.port=5173
traefik.http.routers.app-web.priority=1
```

### **Environment Variables:**
```bash
NODE_ENV=production
PORT=3002  ← Changed from 3001!
FRONTEND_URL=https://sysinspect.skynet97.org
JWT_SECRET=<your-32-char-secret>

CLOUDKIT_CONTAINER_ID=<from-xcode>
CLOUDKIT_ENVIRONMENT=production
CLOUDKIT_API_TOKEN=<from-cloudkit-dashboard>
CLOUDKIT_SERVER_KEY_ID=<from-cloudkit-dashboard>
CLOUDKIT_PRIVATE_KEY=<from-cloudkit-dashboard>
```

---

## 📊 **Port Mapping**

```
User Request → Traefik → Container

https://sysinspect.skynet97.org/
  → Traefik routes to Port 5173
  → serve returns React app

https://sysinspect.skynet97.org/api/health
  → Traefik routes to Port 3002
  → Express API returns health status
```

---

## ✅ **What's Fixed**

| Component | Old Port | New Port | Status |
|-----------|----------|----------|--------|
| Backend API | 3001 (conflict!) | 3002 | ✅ Available |
| Frontend | 5173 | 5173 | ✅ No change |
| Supabase | 3001 | 3001 | ✅ No conflict |

---

## 🚀 **Deploy Now!**

### **1. Push to Git**
```bash
git push origin main
```

### **2. Configure Coolify**

**Ports:**
- Primary: `5173` (Frontend)
- Additional: `3002` with path `/api` ← Use 3002 not 3001!

**Environment:**
- Set `PORT=3002`
- Set all other CloudKit variables

### **3. Deploy!**

Click "Deploy" button.

**Build time:** 5-10 minutes

---

## 🧪 **Test After Deployment**

```bash
# Frontend
curl https://sysinspect.skynet97.org/
# Should return HTML

# Backend API (now on port 3002 internally, /api externally)
curl https://sysinspect.skynet97.org/api/health
# Should return {"status":"ok","timestamp":"..."}
```

---

## 📋 **Final Checklist**

- [x] Port changed from 3001 to 3002
- [x] All files updated
- [x] Documentation updated
- [x] Committed to Git
- [ ] **Push to Git**
- [ ] **Set PORT=3002 in Coolify env vars**
- [ ] **Configure ports: 5173 and 3002**
- [ ] **Deploy**
- [ ] **Test both endpoints**

---

## 🎉 **Summary**

```
╔═══════════════════════════════════════════╗
║                                           ║
║   ✅ PORT CONFLICT RESOLVED! ✅          ║
║                                           ║
║  Old Backend Port:   3001 (Supabase!)    ║
║  New Backend Port:   3002 (Available!)   ║
║  Frontend Port:      5173 (Unchanged)    ║
║                                           ║
║  Traefik:            Routes /api → 3002  ║
║  Cloudflared:        Compatible          ║
║  Status:             Ready to Deploy     ║
║                                           ║
╚═══════════════════════════════════════════╝
```

---

**Port conflict resolved! Deploy now with port 3002!** 🚀
