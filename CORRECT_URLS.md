# ✅ Correct URLs for Testing the Webapp

## 🚨 **Important: Port Numbers Are Internal!**

You **NEVER** put port numbers in the URL when using Traefik/Coolify.

### ❌ **WRONG:**
```
https://sysinspect.skynet97.org/api:3002
https://sysinspect.skynet97.org:3002
https://sysinspect.skynet97.org:5173
```

### ✅ **CORRECT:**
```
https://sysinspect.skynet97.org/
https://sysinspect.skynet97.org/api/health
https://sysinspect.skynet97.org/api/customers
```

---

## 🌐 **How Traefik Routing Works**

Traefik (Coolify's reverse proxy) handles ALL routing internally:

```
User Request → Cloudflare → Traefik → Docker Container
                                        ├─ Port 5173 (Frontend)
                                        └─ Port 3002 (Backend)
```

**Traefik Configuration:**
- `Path: /` → Routes to Port **5173** (Frontend)
- `Path: /api` → Routes to Port **3002** (Backend)

The ports (**5173** and **3002**) are **INSIDE** the Docker container and are **NEVER** visible in URLs!

---

## 📋 **Test These URLs**

### **1. Frontend (Port 5173 internally):**
```bash
# Homepage - should show React app
curl https://sysinspect.skynet97.org/

# Login page
https://sysinspect.skynet97.org/login

# Dashboard (after login)
https://sysinspect.skynet97.org/dashboard
```

### **2. Backend API (Port 3002 internally, /api externally):**
```bash
# API root - shows available endpoints
curl https://sysinspect.skynet97.org/api/

# Health check
curl https://sysinspect.skynet97.org/api/health

# Login endpoint
curl -X POST https://sysinspect.skynet97.org/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com","password":"yourpass"}'

# Customers (requires auth token)
curl https://sysinspect.skynet97.org/api/customers \
  -H "Authorization: Bearer <your-token>"
```

---

## 🔍 **Understanding the Error**

### **Your Error:**
```
URL: https://sysinspect.skynet97.org/api:3002
Error: "Cannot GET /"
```

### **What Happened:**
1. Browser tried to access `https://sysinspect.skynet97.org/api:3002`
2. The `:3002` was interpreted as **part of the URL path**, not a port
3. Traefik routed to backend (because path starts with `/api`)
4. Backend received request for path `/api:3002`
5. No route matches `/api:3002`
6. Backend returns "Cannot GET /"

### **The Fix:**
```bash
# Remove the :3002 from URL
# Traefik automatically routes /api to port 3002
curl https://sysinspect.skynet97.org/api/health
```

---

## 🔧 **Coolify Configuration Check**

Make sure in Coolify you have:

### **Port Configuration:**
```
Primary Port: 5173
Path: /

Additional Port: 3002
Path: /api
Strip Prefix: NO
```

This tells Traefik:
- Requests to `https://sysinspect.skynet97.org/` → Port 5173
- Requests to `https://sysinspect.skynet97.org/api/*` → Port 3002

---

## 🧪 **Step-by-Step Testing**

### **Test 1: Frontend Root**
```bash
curl -I https://sysinspect.skynet97.org/
```
**Expected:** `200 OK` with HTML content (React app)

### **Test 2: Backend API Root**
```bash
curl https://sysinspect.skynet97.org/api/
```
**Expected:**
```json
{
  "message": "Systems Inspector API",
  "version": "1.0.0",
  "endpoints": {
    "health": "/api/health",
    "auth": "/api/auth/login",
    ...
  }
}
```

### **Test 3: Health Check**
```bash
curl https://sysinspect.skynet97.org/api/health
```
**Expected:**
```json
{
  "status": "ok",
  "timestamp": "2026-01-31T..."
}
```

### **Test 4: Login**
```bash
curl -X POST https://sysinspect.skynet97.org/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "testpass"
  }'
```
**Expected (if user exists):**
```json
{
  "token": "eyJ...",
  "user": {
    "userId": "...",
    "email": "test@example.com"
  }
}
```

---

## ⚠️ **Common Mistakes**

### **1. Including Port in URL**
❌ `https://sysinspect.skynet97.org:3002`  
✅ `https://sysinspect.skynet97.org/api/health`

### **2. Wrong Path Format**
❌ `https://sysinspect.skynet97.org/api:3002`  
✅ `https://sysinspect.skynet97.org/api/health`

### **3. Missing /api Prefix**
❌ `https://sysinspect.skynet97.org/customers`  
✅ `https://sysinspect.skynet97.org/api/customers`

### **4. Accessing Backend Directly**
❌ `http://localhost:3002/customers` (only works inside container)  
✅ `https://sysinspect.skynet97.org/api/customers` (via Traefik)

---

## 🎯 **Quick Reference**

| What | URL |
|------|-----|
| **Frontend** | `https://sysinspect.skynet97.org/` |
| **Login Page** | `https://sysinspect.skynet97.org/login` |
| **API Root** | `https://sysinspect.skynet97.org/api/` |
| **API Health** | `https://sysinspect.skynet97.org/api/health` |
| **API Login** | `https://sysinspect.skynet97.org/api/auth/login` |
| **API Customers** | `https://sysinspect.skynet97.org/api/customers` |

**Remember:** NO port numbers in URLs! Traefik handles everything! 🚀

---

## 📊 **How to Debug**

### **If you get "Cannot GET /":**
1. You're hitting the backend at the wrong path
2. Check: Did you include `/api` in the URL?
3. Check: Are you using `:3002` or `:5173` in URL? Remove it!

### **If you get 404:**
1. Frontend path issue → Check if frontend is running on 5173
2. Backend path issue → Check if path starts with `/api`
3. Traefik config issue → Check Coolify port configuration

### **If you get 502 Bad Gateway:**
1. Container not running → Check Coolify logs
2. Port not exposed → Check Dockerfile `EXPOSE` statements
3. Service not started → Check `docker-entrypoint.sh`

---

## ✅ **Summary**

```
╔════════════════════════════════════════════╗
║                                            ║
║   ✅ CORRECT URL FORMAT ✅                ║
║                                            ║
║  Frontend:  https://sysinspect.../        ║
║  Backend:   https://sysinspect.../api/... ║
║                                            ║
║  ❌ DON'T:  Use :3002 or :5173           ║
║  ✅ DO:     Let Traefik handle ports     ║
║                                            ║
╚════════════════════════════════════════════╝
```

**Traefik routes paths, not ports!** 🎯
