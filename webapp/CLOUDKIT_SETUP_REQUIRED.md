# ⚠️ CloudKit Configuration Required!

## 🚨 **Issue: Blank Screen After Login**

If you see a blank screen after logging in with this console error:
```
TypeError: t.slice(...).map is not a function
```

This means **CloudKit environment variables are not configured** in Coolify.

---

## ✅ **Solution: Configure CloudKit in Coolify**

### **Required Environment Variables:**

You MUST add these environment variables in Coolify:

```bash
# CloudKit Container ID (from Xcode)
CLOUDKIT_CONTAINER_ID=iCloud.com.yourapp.SystemsInspector

# CloudKit Environment
CLOUDKIT_ENVIRONMENT=production  # or 'development'

# CloudKit API Token (from CloudKit Dashboard)
CLOUDKIT_API_TOKEN=your-cloudkit-api-token-here

# CloudKit Server-to-Server Key ID
CLOUDKIT_SERVER_KEY_ID=your-server-key-id-here

# CloudKit Private Key (ecdsaPrivateKey from .p8 file)
CLOUDKIT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----
Your private key content here
-----END PRIVATE KEY-----"
```

---

## 📋 **How to Get CloudKit Credentials**

### **1. Container ID (from Xcode):**
- Open your iOS project in Xcode
- Select your app target → Signing & Capabilities
- Under "iCloud", you'll see the container ID
- Example: `iCloud.com.yourcompany.SystemsInspector`

### **2. API Token & Server Key:**
- Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- Select your container
- Go to **API Access** section
- Create a **Server-to-Server Key**:
  - This generates a `.p8` file
  - Save the **Key ID** (you'll need this for `CLOUDKIT_SERVER_KEY_ID`)
  - Download the `.p8` file

### **3. Extract Private Key from .p8 file:**

```bash
# View the private key
cat ecdsaPrivateKey.p8

# Copy everything including the BEGIN/END lines
# Paste into CLOUDKIT_PRIVATE_KEY environment variable
```

**Important:** Keep the line breaks in the private key! Use quotes around it.

### **4. API Token:**
- In CloudKit Dashboard → API Access
- Generate an **API Token**
- Copy the token value for `CLOUDKIT_API_TOKEN`

---

## 🔧 **Configure in Coolify**

### **Step 1: Go to Environment Variables**
In Coolify, navigate to your webapp deployment:
- Click on "Environment Variables"
- Add each variable listed above

### **Step 2: Use Multiline Editor for Private Key**
For `CLOUDKIT_PRIVATE_KEY`:
- Click "Add" → Enter variable name
- Paste the entire private key including:
  ```
  -----BEGIN PRIVATE KEY-----
  (your key content)
  -----END PRIVATE KEY-----
  ```
- Coolify will handle the multiline format

### **Step 3: Redeploy**
- After adding all variables
- Click "Deploy" to rebuild with new config
- The webapp should now work!

---

## 🧪 **Test CloudKit Configuration**

After redeploying, test the API:

```bash
# Get auth token first
TOKEN=$(curl -X POST https://sysinspect.skynet97.org/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com","password":"yourpassword"}' \
  | jq -r '.token')

# Test customers endpoint
curl https://sysinspect.skynet97.org/api/customers \
  -H "Authorization: Bearer $TOKEN"

# Should return an array of customers (or empty array [])
# Should NOT return an error object
```

---

## 🔍 **Check Logs for Errors**

In Coolify, check the container logs:

```bash
# Look for these messages:
✅ Good: "CloudKit connected"
❌ Bad: "CloudKit not configured!"
❌ Bad: "CloudKit API Error:"
```

---

## ⚡ **Quick Fix Summary**

```
Problem: Blank screen after login
Cause: CloudKit env vars missing
Fix: Add 5 CloudKit variables in Coolify
Result: Webapp shows customers/inspections
```

---

## 🎯 **Environment Variables Checklist**

- [ ] `CLOUDKIT_CONTAINER_ID` - from Xcode
- [ ] `CLOUDKIT_ENVIRONMENT` - "production" or "development"
- [ ] `CLOUDKIT_API_TOKEN` - from CloudKit Dashboard
- [ ] `CLOUDKIT_SERVER_KEY_ID` - from .p8 file download
- [ ] `CLOUDKIT_PRIVATE_KEY` - content of .p8 file

Plus the existing variables:
- [ ] `NODE_ENV=production`
- [ ] `PORT=3002`
- [ ] `FRONTEND_URL=https://sysinspect.skynet97.org`
- [ ] `JWT_SECRET` (32+ characters)

---

## 📚 **Resources**

- [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard)
- [CloudKit Web Services Reference](https://developer.apple.com/documentation/cloudkitjs)
- [CloudKit Server-to-Server Authentication](https://developer.apple.com/documentation/cloudkit/managing_icloud_containers_with_the_cloudkit_database_app)

---

**Once CloudKit is configured, the blank screen will be resolved!** 🎉
