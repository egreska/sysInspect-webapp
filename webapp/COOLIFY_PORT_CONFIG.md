# 🔧 Coolify Port Configuration Fix

**Issue:** 404 Error - Domain not routing to container  
**Cause:** Coolify doesn't know which port to use  
**Solution:** Configure port mapping in Coolify settings

---

## ❌ **The Problem**

```
Build: ✅ Succeeded
Container: ✅ Running
Domain Access: ❌ 404 Error
```

**Root Cause:**
Your container exposes TWO ports:
- Port **5173** - Frontend (React app)
- Port **3001** - Backend API

Coolify needs to be explicitly told which port to route traffic to.

---

## ✅ **The Solution**

### **Configure Port in Coolify**

1. **Go to your application in Coolify**
2. **Navigate to "Ports" or "Network" section**
3. **Set the exposed port**

### **Option 1: Single Port (Frontend Only) - RECOMMENDED**

**Configuration:**
```
Port: 5173
```

This routes all traffic to the frontend (port 5173).

**Then update frontend to proxy API requests:**

In `webapp/frontend/vite.config.ts`, ensure proxy is configured:
```typescript
server: {
  proxy: {
    '/api': {
      target: 'http://localhost:3001',
      changeOrigin: true
    }
  }
}
```

**BUT** this only works in development. For production, we need a different approach.

---

### **Option 2: Path-Based Routing (Both Ports) - BETTER**

Configure Coolify to route based on path:

**In Coolify → Network/Ports:**
```
Main Port: 5173 (frontend)

Additional Configuration:
- Path: / → Port 5173 (frontend)
- Path: /api → Port 3001 (backend)
```

**Or in Coolify labels/annotations:**
```
traefik.http.routers.app.rule=Host(`sysinspect.skynet97.org`)
traefik.http.routers.app.service=frontend
traefik.http.services.frontend.loadbalancer.server.port=5173

traefik.http.routers.api.rule=Host(`sysinspect.skynet97.org`) && PathPrefix(`/api`)
traefik.http.routers.api.service=backend
traefik.http.services.backend.loadbalancer.server.port=3001
```

---

### **Option 3: Use Single Port with Nginx (BEST for Production)**

**Problem with current setup:**
- Two separate services on different ports
- Complex routing configuration needed

**Better solution:**
Add Nginx to handle routing internally.

---

## 🚀 **Quick Fix: Use Frontend Port**

**Simplest solution right now:**

1. **In Coolify → Ports section:**
   ```
   Port: 5173
   ```

2. **Then modify the frontend API calls to use relative URLs**

This means your frontend at `https://sysinspect.skynet97.org` will be accessible, but API calls won't work yet.

---

## 🔧 **Better Solution: Add Nginx Reverse Proxy**

Let me create an improved Dockerfile that uses Nginx to handle routing:

### **New Architecture:**
```
Browser → Coolify (Port 80/443)
          ↓
      Nginx (Port 8080)
          ↓
     ┌────┴────┐
     ↓         ↓
Frontend    Backend
(5173)      (3001)
```

This way:
- One exposed port (8080)
- Nginx routes `/api/*` to backend
- Nginx serves frontend for everything else
- Coolify only needs to map port 8080

---

## 📝 **Immediate Action**

### **Step 1: Check Current Port Configuration**

In Coolify, go to your application:
1. Click on "Network" or "Ports"
2. Check what port is configured
3. If no port is set, that's the problem!

### **Step 2: Set Port to 5173**

In Coolify:
```
Exposed Port: 5173
```

Save and redeploy.

### **Step 3: Test**

```bash
curl https://sysinspect.skynet97.org
```

You should now see the frontend!

**BUT:** API calls might fail because they're trying to reach port 3001.

---

## 🎯 **Recommended Next Steps**

### **1. Verify Port in Coolify**
- Set main port to **5173**
- This will make the frontend accessible

### **2. Then I'll Create Nginx-based Setup**
- Single exposed port
- Proper routing for both frontend and backend
- Production-ready configuration

---

## 📋 **Quick Checklist**

- [ ] Check Coolify port configuration
- [ ] Set port to 5173
- [ ] Test frontend access
- [ ] Check if API calls work
- [ ] If API fails, we'll add Nginx

---

**Let me know what port (if any) is currently configured in Coolify, and I'll help you fix it!**
