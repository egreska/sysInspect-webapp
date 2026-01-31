# Visual Testing Guide 👁️

## What You Should See When Testing

---

## 1. Account Lockout Feature 🔒

### Login Screen Changes:

**Before implementing features:**
```
┌────────────────────────┐
│      Systems Inspector  │
├────────────────────────┤
│ Email: [          ]     │
│ Password: [       ]     │
│ [    Log In      ]      │
│ [  Log In with Face ID] │
│ [ Create New Account ]  │
└────────────────────────┘
```

**After implementing features:**
```
┌────────────────────────┐
│      Systems Inspector  │
├────────────────────────┤
│ Email: [          ]     │
│ Password: [       ]     │
│ [    Log In      ]      │
│ [  Log In with Face ID] │
│ [  Forgot Password?  ]  ← NEW!
│ [ Create New Account ]  │
└────────────────────────┘
```

### Error Messages:

**Attempt 1:**
```
┌──────────────────────────────┐
│        Login Failed          │
├──────────────────────────────┤
│ Invalid email or password.   │
│ 4 attempts remaining before  │
│ account lockout.             │
│                              │
│           [  OK  ]           │
└──────────────────────────────┘
```

**Attempt 5:**
```
┌──────────────────────────────┐
│       Account Locked         │
├──────────────────────────────┤
│ Too many failed login        │
│ attempts. Please try again   │
│ in 14 minutes, 58 seconds.   │
│                              │
│           [  OK  ]           │
└──────────────────────────────┘
```

---

## 2. Forgot Password Flow 🔑

### Step 1: Forgot Password Screen
```
┌────────────────────────────────┐
│       Reset Password           │
├────────────────────────────────┤
│ Enter your email and answer    │
│ your security question to      │
│ reset your password.           │
│                                │
│ Email: [                 ]     │
│                                │
│ [     Check Email      ]       │
│                                │
│         [Cancel]               │
└────────────────────────────────┘
```

### Step 2: Security Question Appears
```
┌────────────────────────────────┐
│       Reset Password           │
├────────────────────────────────┤
│ What was the name of your      │
│ first pet?                     │
│                                │
│ Your Answer: [           ]     │
│                                │
│ New Password: [         ]      │
│ Confirm: [              ]      │
│                                │
│ Password must be at least 8    │
│ characters with uppercase...   │
│                                │
│ [    Reset Password    ]       │
│         [Cancel]               │
└────────────────────────────────┘
```

---

## 3. Account Creation with Security Question 🔐

### Enhanced Account Creation:
```
┌────────────────────────────────┐
│      Create Account            │
├────────────────────────────────┤
│ Email: [                 ]     │
│ Password: [              ]     │
│ Confirm: [               ]     │
│                                │
│ Security Question (for         │ ← NEW!
│ password recovery):            │
│                                │
│ [Select a Security Question]   │ ← NEW!
│                                │
│ Your Answer: [           ]     │ ← NEW!
│ (for password recovery)        │
│                                │
│ [    Create Account    ]       │
└────────────────────────────────┘
```

### Security Question Picker:
```
┌────────────────────────────────┐
│   Select Security Question     │
├────────────────────────────────┤
│ What was the name of your      │
│ first pet?                     │
├────────────────────────────────┤
│ What city were you born in?    │
├────────────────────────────────┤
│ What is your mother's maiden   │
│ name?                          │
├────────────────────────────────┤
│ ... (7 more questions)         │
├────────────────────────────────┤
│          [Cancel]              │
└────────────────────────────────┘
```

---

## 4. Image Caching Behavior 🖼️

### Inspection View - First Load:
```
Console:
📸 Loading photo from CloudKit data (2,450,621 bytes)
💾 Image saved to disk cache: photo_ABC123

Time: ~200-500ms
```

### Inspection View - Second Load (Same Session):
```
Console:
📸 Image loaded from memory cache: photo_ABC123

Time: <1ms (instant!)
```

### Inspection View - After App Restart:
```
Console:
📸 Image loaded from disk cache: photo_ABC123

Time: ~10ms (very fast!)
```

### Settings - Cache Management:
```
┌────────────────────────────────┐
│         Performance            │
├────────────────────────────────┤
│ Clear Image Cache    [2.3 MB]  │ ← Shows size!
└────────────────────────────────┘

Tap to see:
┌────────────────────────────────┐
│     Clear Image Cache          │
├────────────────────────────────┤
│ This will clear 2.3 MB of      │
│ cached images. Images will be  │
│ reloaded from Core Data when   │
│ needed.                        │
│                                │
│ [Cancel] [Clear Cache]         │
└────────────────────────────────┘
```

---

## 5. Customer List Pagination 📄

### Customer Directory - Initial Load (50+ customers exist):
```
┌────────────────────────────────┐
│         Customers         [+]  │
├────────────────────────────────┤
│ [Search Customers         ]    │
├────────────────────────────────┤
│ ABC Company                    │
│ Site: Warehouse A              │
│ Contact: John Doe              │
│ 3 inspections   Added: 1/15/26 │
├────────────────────────────────┤
│ ... (19 more customers) ...    │
├────────────────────────────────┤
│ ⭕ Loading more customers...   │ ← Loading indicator!
└────────────────────────────────┘

Console:
📊 Total customers: 50
📄 Fetched page 1: 20 customers
📊 Loaded 20/50 customers
```

### After Scrolling:
```
┌────────────────────────────────┐
│         Customers         [+]  │
├────────────────────────────────┤
│ ... (40 customers shown) ...   │
├────────────────────────────────┤
│ ⭕ Loading more customers...   │
└────────────────────────────────┘

Console:
🔄 Prefetching more customers...
📄 Fetched page 2: 20 customers
📊 Loaded 40/50 customers
```

### When All Loaded:
```
┌────────────────────────────────┐
│         Customers         [+]  │
├────────────────────────────────┤
│ ... (all 50 customers) ...     │
│                                │
│ (No loading indicator)         │
└────────────────────────────────┘

Console:
📊 Loaded 50/50 customers
```

---

## Console Output Examples

### Successful Login Flow:
```
🔵 LoginViewController: Login button tapped
✅ Using secure password verification
✅ Authentication successful
🔵 LoginViewController: Performing successful login
🔵 LoginViewController: Transitioning to MainTabBarController
✅ Account lockout: Cleared lockout data for user@example.com after successful login
```

### Account Lockout Flow:
```
🔵 LoginViewController: Login button tapped
❌ Authentication failed - invalid password
🔒 Account lockout: Failed attempt 1/5 for user@example.com
🔵 LoginViewController: Login button tapped
❌ Authentication failed - invalid password
🔒 Account lockout: Failed attempt 2/5 for user@example.com
... (3 more attempts) ...
🔒 Account lockout: Failed attempt 5/5 for user@example.com
⛔ Account locked for user@example.com - too many failed attempts
```

### Password Recovery Flow:
```
🔵 LoginViewController: Forgot password button tapped
✅ Security question set for user@example.com
✅ Security answer verified
✅ Password reset successful for user@example.com
🔓 Account manually unlocked for user@example.com
```

### Image Caching Flow:
```
📸 Loading photo from CloudKit data (2,450,621 bytes)
💾 Image saved to disk cache: photo_ABC123
📸 Image loaded from memory cache: photo_ABC123
📸 Image loaded from disk cache: photo_ABC123
🗑️ Memory cache cleared
🗑️ Disk cache cleared
✅ Disk cache trimmed to 78.5 MB
```

### Pagination Flow:
```
📊 Total customers: 150
📄 Fetched page 1: 20 customers
📊 Loaded 20/150 customers
📄 Loading more customers...
🔄 Prefetching more customers...
📄 Fetched page 2: 20 customers
📊 Loaded 40/150 customers
📄 Fetched page 3: 20 customers
📊 Loaded 60/150 customers
```

---

## Expected Behavior Summary

### ✅ Account Lockout:
- 5 wrong attempts → Lock for 15 minutes
- Shows remaining time
- Clears on successful login

### ✅ Password Recovery:
- "Forgot Password?" button on login
- Select security question during signup
- Answer question to reset password
- New password must meet requirements

### ✅ Image Caching:
- First load: ~200-500ms
- Cached load: <1ms (instant)
- Shows cache size in Settings
- Can clear cache manually

### ✅ Pagination:
- Loads 20 customers at a time
- "Loading more..." indicator
- Auto-loads when scrolling
- Search loads all results

---

## Performance Metrics

### You Should Observe:

**App Launch:**
- Opens in < 1 second ✅

**Customer List (100 customers):**
- Initial: Shows 20 in ~100ms ✅
- Memory: ~30 MB (not 150 MB) ✅

**Images (20 photos):**
- First view: 4-10 seconds
- Cached view: <1 second ✅

**Scrolling:**
- Smooth with 1000+ customers ✅

---

## Testing Checklist

### Quick Test (5 minutes):
- [ ] Build succeeds
- [ ] App launches
- [ ] Login works
- [ ] Can create account
- [ ] Features visible in UI

### Full Test (30 minutes):
- [ ] Account lockout (5 attempts)
- [ ] Password recovery (full flow)
- [ ] Image caching (verify console)
- [ ] Pagination (50+ customers)
- [ ] All console messages correct

---

## Files to Review

**Start Here:** 
1. 📖 `IMPLEMENTATION_SUMMARY.md` - Overview
2. 🧪 `BUILD_AND_TEST_GUIDE.md` - Detailed testing
3. 📚 `NEW_FEATURES_IMPLEMENTED.md` - Feature details

**Reference:**
4. 📋 `QUICK_REFERENCE.md` - This file
5. 🔒 `SECURITY_IMPLEMENTATION_COMPLETE.md` - Security

---

## Next Steps

1. **Build in Xcode** (Cmd+B)
2. **Run on Simulator** (Cmd+R)
3. **Test Each Feature** (5 min each)
4. **Check Console** (verify logs)
5. **Test on Device** (real performance)
6. **Submit to TestFlight** 🚀

---

**Status:** ✅ READY TO TEST  
**Expected Result:** Everything works perfectly!
