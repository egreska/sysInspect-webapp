# CloudKit Setup Guide - Systems Inspector

Complete guide for configuring CloudKit to access data from your iOS app.

## 🎯 Overview

The web app uses **CloudKit JS** (browser SDK) with Sign in with Apple. The backend uses **CloudKit Web Services** (Server-to-Server) for optional server-side operations.

### Web App (CloudKit JS)
- **Auth:** Sign in with Apple (same Apple ID as iOS app)
- **Data:** Fetched directly from CloudKit in the browser
- **Config:** API Token from CloudKit Dashboard → API Access → API Tokens

### Backend (optional)
- **Auth:** Server-to-Server key
- **Config:** See Step 3–5 below

---

## 📋 Prerequisites

- Apple Developer Account (paid)
- iOS app with CloudKit enabled
- Access to Apple Developer Portal
- CloudKit data already created by iOS app

---

## 🔧 Step-by-Step Setup

### Step 1: Find Your CloudKit Container ID

1. Open **Xcode**
2. Select your iOS project
3. Go to **Signing & Capabilities** tab
4. Find **iCloud** capability
5. Note your Container ID (e.g., `iCloud.SysInspectDB` – must match webapp)

**Or from Apple Developer Portal:**

1. Go to [developer.apple.com](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **iCloud Containers**
4. Find your container
5. Copy the Container ID

---

### Step 2: Enable CloudKit Web Services

1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com)
2. Sign in with your Apple Developer account
3. Select your Container
4. Verify your data is there:
   - Click **Data** in the sidebar
   - Select **Production** or **Development**
   - Browse **Record Types**: CD_Customer, CD_Inspection, CD_InspectionItem (Core Data + CloudKit prefix)
   - Verify you see your data

---

### Step 3a: API Token (for Web App / CloudKit JS)

1. In CloudKit Dashboard
2. Go to **API Access** → **API Tokens**
3. Click **"+"** to add a new token
4. Enter a name (e.g., `Systems Inspector Web`)
5. **Restrict Allowed Origins** to your real HTTPS site(s) (staging + production). The token is still present in the built JS, but origin limits reduce misuse from other sites.
6. Copy the generated token
7. Add to frontend `.env`: `VITE_CLOUDKIT_API_TOKEN=your-token`

See [SECURITY.md](./SECURITY.md) for rotation, CSP, and incident response.

### Step 3b: Server-to-Server Key (for Backend)

1. In CloudKit Dashboard
2. Go to **API Access** → **Server-to-Server Keys**
3. Click **"+"** to add new key
4. Enter a key name (e.g., `Systems Inspector Web`)
5. Click **Create**
6. **IMPORTANT:** Copy and save:
   - **Key ID** (looks like: `a1b2c3d4e5f6g7h8i9j0`)
   - **Server-to-Server Key** (Starts with `-----BEGIN PRIVATE KEY-----`)

⚠️ **Warning:** You can only view the private key once! Save it securely.

---

### Step 4: Download and Format Private Key

Your private key should look like this:

```
-----BEGIN PRIVATE KEY-----
MIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgYourPrivateKeyContent
hereSpanningMultipleLinesBase64EncodedDataContinuesUntilTheEndMarkerAppears
wEHBDoCAgQs=
-----END PRIVATE KEY-----
```

**For environment variables**, format as a single line with `\n`:

```bash
CLOUDKIT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIGTAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBHkwdwIBAQQgYourPrivateKeyContent\nhereSpanningMultipleLinesBase64EncodedDataContinuesUntilTheEndMarkerAppears\nwEHBDoCAgQs=\n-----END PRIVATE KEY-----"
```

---

### Step 5: Configure Environment Variables

Create or update `backend/.env`:

```bash
# CloudKit Configuration
CLOUDKIT_CONTAINER_ID=iCloud.SysInspectDB
CLOUDKIT_ENVIRONMENT=production
CLOUDKIT_SERVER_KEY_ID=a1b2c3d4e5f6g7h8i9j0
CLOUDKIT_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYour\nPrivate\nKey\nHere\n-----END PRIVATE KEY-----"
```

**Environment Options:**
- `development` - For testing with development data
- `production` - For live production data

---

### Step 6: Test CloudKit Connection

This repository ships a **frontend-only** web app (CloudKit JS in the browser). There is no `backend/` test harness here.

**Verify connectivity:**

1. **CloudKit Dashboard** — Open [CloudKit Dashboard](https://icloud.developer.apple.com/) → your container → **Data** → confirm `CD_Customer` / `CD_Inspection` records in the correct environment (Development vs Production).
2. **Web app** — Build with `VITE_CLOUDKIT_*` set, deploy or run `npm run dev`, sign in with Apple, and open Customers / Dashboard.

If you add a separate Node or server-side CloudKit client later, use Apple’s server-to-server APIs and your own test script.

---

## 🔍 Understanding CloudKit Web Services

### Authentication Flow

```
1. Generate Signature
   ↓
2. Make Request with Signature
   ↓
3. CloudKit Verifies Signature
   ↓
4. Returns Data
```

### Request Format

```javascript
{
  query: {
    recordType: 'Customer',
    filterBy: [{
      fieldName: 'userId',
      comparator: 'EQUALS',
      fieldValue: { value: 'user-id', type: 'STRING' }
    }]
  }
}
```

### Response Format

```javascript
{
  records: [{
    recordName: 'unique-id',
    recordType: 'Customer',
    fields: {
      name: { value: 'ACME Corp' },
      phone: { value: '555-0100' },
      // ... other fields
    }
  }]
}
```

---

## 🐛 Troubleshooting

### Error: "Authentication failed"

**Causes:**
- Invalid private key
- Incorrect key ID
- Wrong container ID

**Solutions:**
1. Regenerate key in CloudKit Dashboard
2. Verify key format (check for line breaks)
3. Ensure key ID matches the key
4. Verify container ID is correct

**Test:**
```bash
# Print your configured values (without exposing full key)
node -e "require('dotenv').config(); console.log('Container:', process.env.CLOUDKIT_CONTAINER_ID); console.log('Key ID:', process.env.CLOUDKIT_SERVER_KEY_ID); console.log('Key Length:', process.env.CLOUDKIT_PRIVATE_KEY?.length);"
```

### Error: "Container not found"

**Causes:**
- Wrong container ID
- Container not enabled for Web Services

**Solutions:**
1. Verify container ID in CloudKit Dashboard
2. Check that API Access is enabled
3. Ensure you're using the correct environment (production vs development)

### Error: "Record not found"

**Causes:**
- No data in CloudKit yet
- Wrong environment (development vs production)
- User doesn't exist

**Solutions:**
1. Verify data exists in CloudKit Dashboard
2. Check you're using correct environment
3. Create test data with iOS app first

### Error: "Signature verification failed"

**Causes:**
- Private key formatting issues
- Time synchronization problems

**Solutions:**
1. Reformat private key with proper line breaks
2. Ensure server time is synchronized (NTP)
3. Regenerate key if needed

---

## 📊 CloudKit Data Structure

### User Record

```javascript
{
  recordType: 'User',
  fields: {
    email: { value: 'user@example.com' },
    userId: { value: 'UUID' },
    passwordHash: { value: 'hash' },
    passwordSalt: { value: 'salt' }
  }
}
```

### Customer Record

```javascript
{
  recordType: 'Customer',
  fields: {
    name: { value: 'ACME Corp' },
    contactName: { value: 'John Doe' },
    phone: { value: '555-0100' },
    address: { value: '123 Main St' },
    city: { value: 'New York' },
    state: { value: 'NY' },
    zipCode: { value: '10001' },
    site: { value: 'Building A' },
    userId: { value: 'UUID' }
  }
}
```

### Inspection Record

```javascript
{
  recordType: 'Inspection',
  fields: {
    date: { value: '2026-01-30T12:00:00Z' },
    inspectorName: { value: 'Jane Inspector' },
    userId: { value: 'UUID' },
    customer: {
      value: { recordName: 'customer-id' },
      type: 'REFERENCE'
    }
  }
}
```

### InspectionItem Record

```javascript
{
  recordType: 'InspectionItem',
  fields: {
    location: { value: 'Warehouse A, Row 5' },
    bayNumber: { value: '10' },
    importance: { value: 'Critical' },
    comments: { value: 'Needs immediate attention' },
    sequenceNumber: { value: 1 },
    upright: { value: true },
    uprightFrontDamage: { value: true },
    // ... many boolean damage fields
    photoURL: {
      value: {
        fileChecksum: 'checksum',
        size: 123456,
        downloadURL: 'https://...'
      },
      type: 'ASSET'
    },
    inspection: {
      value: { recordName: 'inspection-id' },
      type: 'REFERENCE'
    }
  }
}
```

---

## 🔒 Security Best Practices

### 1. Key Management

✅ **DO:**
- Store private key securely (environment variables, secrets manager)
- Use different keys for development/production
- Rotate keys periodically (every 90 days)
- Monitor key usage

❌ **DON'T:**
- Commit keys to Git
- Share keys in logs or errors
- Use production keys in development
- Hardcode keys in source code

### 2. Access Control

✅ **DO:**
- Use server-to-server authentication only
- Validate user ownership of data
- Implement rate limiting
- Log all CloudKit access

❌ **DON'T:**
- Expose CloudKit credentials to client
- Skip user verification
- Allow unrestricted queries
- Return more data than needed

### 3. Data Protection

✅ **DO:**
- Fetch only necessary fields
- Implement pagination
- Cache responses appropriately
- Handle errors gracefully

❌ **DON'T:**
- Fetch all data at once
- Cache sensitive data long-term
- Expose CloudKit errors to users
- Log sensitive data

---

## 📚 Additional Resources

### Apple Documentation
- [CloudKit Web Services](https://developer.apple.com/documentation/cloudkitjs)
- [Server-to-Server Authentication](https://developer.apple.com/documentation/cloudkitjs/cloudkit/server_to_server_key_authentication)
- [CloudKit Dashboard](https://icloud.developer.apple.com)

### Code Examples
- Backend service: `backend/src/services/cloudkit.js`
- API routes: `backend/src/routes/*.js`
- Test script: `backend/test-cloudkit.js`

---

## ✅ Setup Checklist

Before deploying:

- [ ] CloudKit container ID configured
- [ ] Server-to-server key generated
- [ ] Private key downloaded and saved
- [ ] Environment variables configured
- [ ] Test script runs successfully
- [ ] Can fetch user data
- [ ] Can fetch customer data
- [ ] Can fetch inspection data
- [ ] Photos download correctly
- [ ] Error handling works

---

**CloudKit Setup Version:** 1.0  
**Last Updated:** January 30, 2026  
**Platform:** Apple CloudKit Web Services

---

**🎉 CloudKit is configured!**

Your web app can now securely access data from your iOS app via CloudKit!
