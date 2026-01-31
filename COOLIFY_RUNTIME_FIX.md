# 🔧 Coolify Runtime Configuration Fix

**Issue:** Docker runtime error with NVIDIA GPU socket  
**Cause:** Coolify server has GPU runtime enabled by default  
**Solution:** Disable GPU requirements for this container

---

## ❌ **The Error**

```
OCI runtime create failed: runc create failed: unable to start container process: 
error during container init: failed to fulfil mount request: 
open /run/nvidia-persistenced/socket: no such file or directory
```

**Root Cause:**
1. Coolify was trying to use `docker-compose.yml` (for local dev)
2. Server might have GPU runtime enabled by default
3. Webapp doesn't need GPU support

---

## ✅ **Fixes Applied**

### **1. Renamed Local Docker Compose**
```bash
✅ Renamed: docker-compose.yml → docker-compose.local.yml
✅ This prevents Coolify from using the dev compose file
```

### **2. Added .dockerignore**
```
✅ Excludes docker-compose.local.yml from builds
✅ Reduces build context size
✅ Speeds up builds
```

---

## 🚀 **Coolify Configuration**

### **In Coolify Dashboard:**

**1. Build Configuration:**
- Build Pack: `Dockerfile` (not Docker Compose)
- Dockerfile Path: `webapp/Dockerfile`
- Build Context: `webapp/`

**2. Runtime Configuration:**

If the error persists, add this to **Advanced → Docker Run Options**:
```bash
--runtime=runc
```

Or in **Advanced → Additional Labels**:
```
com.docker.compose.service.runtime=runc
```

**3. Resource Settings:**

Ensure **GPU Support** is **DISABLED**:
- Go to Resource Settings
- GPU: Off/Disabled
- Runtime: Default (runc)

---

## 🐛 **If Error Persists**

### **Check Server Configuration**

SSH into your Coolify server and check Docker daemon config:

```bash
# Check Docker daemon config
cat /etc/docker/daemon.json

# If it has "default-runtime": "nvidia", that's the problem
```

**Fix (on server):**
```bash
# Edit daemon config
sudo nano /etc/docker/daemon.json

# Remove or comment out:
# "default-runtime": "nvidia"

# Or explicitly set:
{
  "default-runtime": "runc"
}

# Restart Docker
sudo systemctl restart docker
```

---

## 📝 **Correct Coolify Configuration**

```yaml
# Coolify should build with these settings:
Build:
  Type: Dockerfile
  Path: webapp/Dockerfile
  Context: webapp/

Runtime:
  Runtime: runc (NOT nvidia)
  GPU: Disabled
  
Ports:
  - 3001:3001
  - 5173:5173

Environment Variables:
  NODE_ENV: production
  PORT: 3001
  FRONTEND_URL: https://sysinspect.skynet97.org
  JWT_SECRET: <your-secret>
  CLOUDKIT_*: <your-keys>
```

---

## ✅ **What Changed**

**Files Modified:**
- `docker-compose.yml` → Renamed to `docker-compose.local.yml`
- `.dockerignore` → Created (excludes dev files)

**Coolify Config:**
- Build Type: Dockerfile (not Compose)
- Runtime: Default/runc (not nvidia)
- GPU Support: Disabled

---

## 🚀 **Deploy Again**

After pushing these changes:

1. **Push to Git:**
   ```bash
   git push origin main
   ```

2. **In Coolify:**
   - Verify Build Pack is "Dockerfile"
   - Ensure GPU is disabled
   - Redeploy

3. **Build should succeed now!**

---

## 📊 **Expected Behavior**

```
✅ Coolify uses Dockerfile directly
✅ Docker uses runc runtime (not nvidia)
✅ No GPU socket required
✅ Container starts successfully
✅ Webapp deploys!
```

---

**The webapp doesn't need GPU support. These changes ensure Docker uses the standard runtime.** 🚀
