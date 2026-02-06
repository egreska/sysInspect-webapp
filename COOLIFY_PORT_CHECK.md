# 🔍 Coolify Port Configuration Checklist

## ✅ **Backend is Working!**

You got this response from the backend:
```json
{
  "message": "Systems Inspector API",
  "version": "1.0.0",
  "endpoints": {
    "health": "/health or /api/health",
    "auth": "/api/auth/login",
    "customers": "/api/customers",
    "inspections": "/api/inspections/:id",
    "reports": "/api/reports/inspection/:id"
  }
}
```

This proves the backend is running correctly! ✅

---

## 🔧 **Coolify Port Configuration**

### **The Coolify UI Link Issue:**

Coolify shows: `https://sysinspect.skynet97.org/api:3002`

**This is confusing but ignore it!** Coolify is just indicating "path /api routes to port 3002".

**Use these URLs instead:**
- Frontend: `https://sysinspect.skynet97.org/`
- Backend: `https://sysinspect.skynet97.org/api/*`

---

## 📋 **Check Your Coolify Settings**

Go to Coolify → Your Webapp → **Network/Routing**:

### **Port Configuration Should Be:**

```
┌──────────────────────────────────────────────┐
│ PRIMARY PORT                                 │
├──────────────────────────────────────────────┤
│ Port: 5173                                   │
│ Path: /                                      │
│ (or leave Path empty)                        │
└──────────────────────────────────────────────┘

┌──────────────────────────────────────────────┐
│ ADDITIONAL PORTS                             │
├──────────────────────────────────────────────┤
│ Port: 3002                                   │
│ Path: /api                                   │
│ Strip Prefix: NO (unchecked)                 │
└──────────────────────────────────────────────┘
```

---

## 🧪 **Test These URLs**

### **1. Test Frontend:**
```bash
# Should return HTML (React app)
curl -I https://sysinspect.skynet97.org/

# Or visit in browser - should see login page
```

### **2. Test Backend API:**
```bash
# Should return JSON health status
curl https://sysinspect.skynet97.org/api/health

# Expected:
# {"status":"ok","timestamp":"2026-01-31T..."}
```

### **3. Test Login:**
```bash
curl -X POST https://sysinspect.skynet97.org/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "testpass"
  }'
```

---

## 🔍 **Troubleshooting**

### **If Frontend Doesn't Load:**

**Problem:** `https://sysinspect.skynet97.org/` returns the backend API JSON instead of the React app.

**Cause:** Primary port is set to 3002 instead of 5173, or path priority is wrong.

**Fix:**
1. In Coolify → Network/Routing
2. Make sure Primary Port is **5173** with path `/`
3. Additional Port is **3002** with path `/api`
4. The **PRIMARY** port should be 5173 (not 3002!)

### **If You See "Cannot GET /":**

**Cause:** Path configuration is wrong.

**Fix:** Check that paths are:
- Primary: `/` (or empty)
- Additional: `/api`

### **If Backend API Returns 404:**

**Cause:** Path `/api` not configured for port 3002.

**Fix:** Add Additional Port 3002 with path `/api`.

---

## 📊 **Expected Behavior**

| URL | Routes To | Expected Response |
|-----|-----------|-------------------|
| `https://sysinspect.../` | Port 5173 | React app HTML |
| `https://sysinspect.../login` | Port 5173 | React login page |
| `https://sysinspect.../api/` | Port 3002 | API info JSON |
| `https://sysinspect.../api/health` | Port 3002 | Health status JSON |
| `https://sysinspect.../api/customers` | Port 3002 | Customers JSON (needs auth) |

---

## 🎯 **Current Status**

### ✅ **Working:**
- Backend API is accessible
- Backend responds at `/api/*` paths
- Port 3002 routing is correct

### ❓ **To Check:**
- Does frontend load at `https://sysinspect.skynet97.org/`?
- Is Primary Port set to **5173** in Coolify?

---

## 🚀 **If Frontend Is Missing**

If visiting `https://sysinspect.skynet97.org/` shows:
- Backend API JSON → Port 5173 not configured correctly
- 404 error → Frontend not serving
- Blank page → Frontend built correctly but not serving

**Check Coolify Logs:**
1. Go to Coolify → Your Webapp → Logs
2. Look for:
```
Starting frontend on port 5173...
✅ Frontend ready
```

If you don't see this, the frontend service might not be starting.

---

## 📝 **Quick Fix Commands**

### **In Coolify, set these EXACT settings:**

**Network/Routing:**
```
Primary Port: 5173
Path: /

Click "Add Port"
Port: 3002
Path: /api
Strip Prefix: NO
```

**Then:** Click "Deploy" to apply changes.

---

## ✅ **Summary**

```
╔════════════════════════════════════════════╗
║                                            ║
║   ✅ BACKEND IS WORKING! ✅               ║
║                                            ║
║  Backend API: ✅ Responding correctly     ║
║  Port 3002:   ✅ Accessible via /api      ║
║                                            ║
║  To Check:                                ║
║  - Is frontend at port 5173 working?      ║
║  - Visit https://sysinspect.../ (root)    ║
║  - Should see React login page            ║
║                                            ║
╚════════════════════════════════════════════╝
```

---

**Next Step:** Visit `https://sysinspect.skynet97.org/` (no /api) in your browser. What do you see?
