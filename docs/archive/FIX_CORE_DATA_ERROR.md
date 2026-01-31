# Fix: "User.passwordSalt must have a defined type"

## ✅ FIXED - Now Follow These Steps:

### 1. Clean Build Folder
```
Product → Clean Build Folder (or Cmd+Shift+K)
```

### 2. Delete Derived Data (Important!)
```
In Xcode:
Window → Devices and Simulators → Delete Derived Data

OR manually:
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

### 3. Rebuild
```
Product → Build (or Cmd+B)
```

---

## If Error Persists, Force Core Data Regeneration:

### Option A: In Xcode (Easiest)

1. **Open the data model:**
   - Click on `Systems_Inspector.xcdatamodeld`

2. **Select User entity:**
   - Click on "User" in the left panel

3. **Verify passwordSalt attribute:**
   - Should show: `passwordSalt` | `Binary` | Optional

4. **Force regeneration:**
   - Select the User entity
   - In Data Model Inspector (right panel):
   - Verify "Class" section shows:
     - Module: `Current Product Module`
     - Codegen: `Class Definition`
   - If Codegen is set to "Manual/None", change it to "Class Definition"

5. **Save and rebuild:**
   - File → Save (Cmd+S)
   - Product → Clean Build Folder (Cmd+Shift+K)
   - Product → Build (Cmd+B)

---

### Option B: Manual Core Data Class Generation (If needed)

If automatic generation still fails:

1. **Change Codegen to Manual/None:**
   - Select User entity
   - Data Model Inspector → Codegen: `Manual/None`

2. **Generate classes manually:**
   - Editor → Create NSManagedObject Subclass
   - Select your data model
   - Select "User" entity
   - Click "Next" and "Create"

3. **This will create:**
   - `User+CoreDataClass.swift`
   - `User+CoreDataProperties.swift`

4. **Verify passwordSalt is included:**
   Open `User+CoreDataProperties.swift` and verify it contains:
   ```swift
   @NSManaged public var passwordSalt: Data?
   ```

---

## Verification Steps:

After building successfully:

1. **Run the app**
2. **Check console for:**
   ```
   ✅ Local user created successfully with secure password
   ```

3. **No errors about passwordSalt**

---

## What Was Fixed:

Changed Core Data attribute type from:
```xml
attributeType="Binary Data"  ❌ Wrong
```

To:
```xml
attributeType="Binary"  ✅ Correct
```

Core Data uses "Binary" not "Binary Data" in the XML format.

---

## Still Having Issues?

### Try This Complete Reset:

```bash
# 1. Close Xcode completely

# 2. Clean everything
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# 3. In your project folder
cd "/Users/egreska/Systems Inspector"
rm -rf .build
find . -name "*.xcuserstate" -delete

# 4. Reopen Xcode
# 5. Clean Build Folder (Cmd+Shift+K)
# 6. Build (Cmd+B)
```

---

## Expected Build Output:

When successful, you should see:
```
✅ Build Succeeded
   Compiling UserManager.swift
   Compiling CoreDataManager.swift
   ...
   Build complete
```

No errors about User.passwordSalt

---

## Next Step After Successful Build:

Run the app and test:
1. Create a new user account
2. Log in
3. Check console for security messages

---

**Status:** Fix applied - Clean and rebuild required  
**Expected Time:** 2-3 minutes  
**Complexity:** Simple
