# Firebase Analytics & Crashlytics Setup Guide 🔥

## Complete Integration Guide

**Date:** January 29, 2026  
**Status:** Ready for Firebase Integration

---

## Overview

This guide walks you through integrating Firebase Analytics and Crashlytics into your Systems Inspector iOS app.

---

## Step 1: Create Firebase Project ☁️

### 1.1 Go to Firebase Console
```
1. Visit: https://console.firebase.google.com/
2. Click "Add Project" or "Create a Project"
3. Enter project name: "Systems Inspector"
4. Enable/Disable Google Analytics (recommended: Enable)
5. Choose Analytics account or create new
6. Click "Create Project"
```

### 1.2 Add iOS App
```
1. Click "Add app" → iOS icon
2. iOS bundle ID: com.yourcompany.systemsinspector
   (Get from Xcode: Target → General → Bundle Identifier)
3. App nickname: "Systems Inspector iOS"
4. App Store ID: (Leave empty for now)
5. Click "Register app"
```

### 1.3 Download GoogleService-Info.plist
```
1. Download the GoogleService-Info.plist file
2. DO NOT add it yet - we'll do this in Step 3
3. Keep it safe - you'll need it
```

---

## Step 2: Install Firebase SDK 📦

### 2.1 Install CocoaPods (if not installed)
```bash
sudo gem install cocoapods
```

### 2.2 Navigate to Project Directory
```bash
cd "/Users/egreska/Systems Inspector"
```

### 2.3 Install Dependencies
```bash
pod install
```

**Expected Output:**
```
Analyzing dependencies
Downloading dependencies
Installing Firebase (10.x.x)
Installing FirebaseAnalytics (10.x.x)
Installing FirebaseCrashlytics (10.x.x)
...
Pod installation complete!
```

### 2.4 Important: Use Workspace
```
⚠️ From now on, open the .xcworkspace file, NOT .xcodeproj!

Open: Systems Inspector.xcworkspace
```

---

## Step 3: Add GoogleService-Info.plist 📋

### 3.1 Add to Xcode
```
1. Open Systems Inspector.xcworkspace in Xcode
2. Drag GoogleService-Info.plist into project navigator
3. ✅ Check "Copy items if needed"
4. ✅ Check "Systems Inspector" target
5. Click "Finish"
```

### 3.2 Verify
```
1. Click on GoogleService-Info.plist in navigator
2. Check "Target Membership" in File Inspector
3. ✅ "Systems Inspector" should be checked
```

---

## Step 4: Configure Firebase in AppDelegate 🔧

### 4.1 Import Firebase
```swift
// At top of AppDelegate.swift
import Firebase
```

### 4.2 Initialize Firebase
```swift
func application(_ application: UIApplication, 
                didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    
    // Configure Firebase (ADD THIS FIRST)
    FirebaseApp.configure()
    
    // Rest of your existing code...
    setupCoreData()
    configureAppearance()
    
    return true
}
```

---

## Step 5: Enable Crashlytics 💥

### 5.1 Add Run Script Phase
```
1. Select project in navigator
2. Select "Systems Inspector" target
3. Go to "Build Phases" tab
4. Click "+" → "New Run Script Phase"
5. Name it: "Firebase Crashlytics"
6. Add script:

"${PODS_ROOT}/FirebaseCrashlytics/run"

7. Move it ABOVE "Compile Sources"
```

### 5.2 Add Debug Information Format
```
1. Go to Build Settings
2. Search for "Debug Information Format"
3. Set to "DWARF with dSYM File" for ALL configurations
```

### 5.3 Upload Symbols
```
Build Settings → Add to "Input Files":
${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}

Add to "Output Files":
${DERIVED_FILE_DIR}/${ARCHS}.txt
```

---

## Step 6: Update AnalyticsManager 📊

### 6.1 Uncomment Firebase Code

In `AnalyticsManager.swift`, find and uncomment:

```swift
// BEFORE (commented out):
// Analytics.logEvent(eventName, parameters: enrichedParameters)

// AFTER (uncommented):
Analytics.logEvent(eventName, parameters: enrichedParameters)
```

### 6.2 Add Firebase Import
```swift
// At top of AnalyticsManager.swift
import FirebaseAnalytics
import FirebaseCrashlytics
```

### 6.3 Update All TODO Comments
Search for `// TODO:` in AnalyticsManager.swift and implement:

```swift
// User ID
Analytics.setUserID(userID)
Crashlytics.crashlytics().setUserID(userID)

// User Properties  
Analytics.setUserProperty(value, forName: name)

// Screen Views
Analytics.logEvent(AnalyticsEventScreenView, parameters: [...])

// Errors
Crashlytics.crashlytics().record(error: error)
```

---

## Step 7: Test Integration ✅

### 7.1 Test Analytics
```
1. Build and run app (Cmd+R)
2. Perform some actions (login, create customer, etc.)
3. Check Xcode console for analytics logs:
   📊 Analytics Event: login
   📊 Analytics Event: customer_created
```

### 7.2 Test Crashlytics
```
1. Add test crash button (temporary):

Button("Test Crash") {
    fatalError("Test crash for Crashlytics")
}

2. Run app, tap button
3. Relaunch app
4. Check Firebase Console → Crashlytics
   (May take 5-10 minutes to appear)
```

### 7.3 Verify in Firebase Console
```
1. Go to Firebase Console
2. Select your project
3. Analytics → Dashboard
   - Should see events appearing
   - May take a few hours for initial data

4. Crashlytics → Dashboard  
   - Should see crashes (if any)
   - Verify symbolication works
```

---

## Step 8: Privacy & App Store Compliance 📱

### 8.1 Update Info.plist
Add privacy descriptions (if not already present):

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to attach inspection photos.</string>

<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take inspection photos.</string>
```

### 8.2 Update Privacy Policy
Add section about analytics collection:

```
Data Collection:
- We collect anonymized usage data to improve the app
- We collect crash reports to fix bugs
- No personal information is shared with third parties
- You can opt-out in Settings
```

### 8.3 App Store Privacy Declarations
```
Data Collection:
- Crash Data (for app functionality)
- Product Interaction (for analytics)
- Other Usage Data (for app functionality)

Not Linked to User:
- All data is anonymized
```

---

## Step 9: Optional Features 🌟

### 9.1 Add Opt-Out Toggle
In SettingsViewController, add:

```swift
private let analyticsToggle = UISwitch()

// In settings
if analyticsToggle.isOn {
    AnalyticsManager.shared.enableAnalytics()
} else {
    AnalyticsManager.shared.disableAnalytics()
}
```

### 9.2 Add Performance Monitoring
```
// In Podfile
pod 'Firebase/Performance'

// In code
let trace = Performance.startTrace(name: "fetch_customers")
// ... do work ...
trace?.stop()
```

### 9.3 Add Remote Config
```
// In Podfile  
pod 'Firebase/RemoteConfig'

// In code
let remoteConfig = RemoteConfig.remoteConfig()
remoteConfig.fetch { status, error in
    if status == .success {
        remoteConfig.activate()
    }
}
```

---

## Step 10: Monitoring & Debugging 🔍

### 10.1 Enable Debug Logging
```swift
// In AppDelegate.swift (before FirebaseApp.configure())
#if DEBUG
FirebaseConfiguration.shared.setLoggerLevel(.debug)
#endif

FirebaseApp.configure()
```

### 10.2 Test Events in Console
```
1. Run app on simulator
2. Check Xcode console for Firebase logs
3. Look for:
   - "Firebase configured successfully"
   - "Analytics event logged: ..."
   - "Crashlytics initialized"
```

### 10.3 Monitor in Production
```
Firebase Console:
- Analytics → Events (real-time)
- Analytics → Users (active users)
- Crashlytics → Issues (crash-free rate)
- Performance → Dashboard (if enabled)
```

---

## Current Implementation Status ✅

### Already Implemented in Code:
✅ AnalyticsManager class created  
✅ Event tracking methods defined  
✅ Integration points added:
  - Login/Logout events
  - Account creation
  - Account lockout
  - Password reset
  - Image cache hits/misses
  - Screen views
  - Error tracking

### TODO (After Firebase Setup):
1. ⏳ Run `pod install`
2. ⏳ Add GoogleService-Info.plist
3. ⏳ Import Firebase in AppDelegate
4. ⏳ Call FirebaseApp.configure()
5. ⏳ Uncomment Firebase code in AnalyticsManager
6. ⏳ Add Firebase imports to AnalyticsManager
7. ⏳ Test in Firebase Console

---

## Analytics Events Currently Tracked 📊

### Authentication:
- `login` - User login (success/failure, method)
- `logout` - User logout
- `account_created` - New account
- `password_reset` - Password reset (success/failure)
- `account_locked` - Account lockout triggered

### Customers:
- `customer_created` - New customer added
- `customer_viewed` - Customer details viewed
- `customer_edited` - Customer updated
- `customer_deleted` - Customer removed
- `customer_search` - Search performed

### Inspections:
- `inspection_created` - New inspection
- `inspection_viewed` - Inspection viewed
- `inspection_photo_added` - Photo attached
- `report_generated` - PDF report created

### Performance:
- `performance_metric` - Operation timing
- `cache_hit` - Successful cache lookup
- `cache_miss` - Cache miss
- `memory_usage` - Memory statistics

### Errors:
- `error_occurred` - Error with context
- `non_fatal_error` - Non-crash error
- `crash` - App crash

### User Actions:
- `screen_view` - Screen navigation
- Custom events as needed

---

## Crashlytics Features 💥

### Automatic Crash Reporting:
- ✅ Captures all crashes
- ✅ Full stack traces
- ✅ Device information
- ✅ OS version
- ✅ App version
- ✅ User actions before crash

### Custom Logging:
```swift
// Log custom keys for context
Crashlytics.crashlytics().setCustomValue(value, forKey: key)

// Log non-fatal errors
Crashlytics.crashlytics().record(error: error)
```

### User Identification:
```swift
// Set user ID for crash tracking
Crashlytics.crashlytics().setUserID(userID)
```

---

## Privacy Considerations 🔐

### What Firebase Collects:
- Device model
- OS version
- App version
- Screen resolutions
- Event timestamps
- Crash data
- Performance metrics

### What We Don't Send:
- ❌ User emails
- ❌ User passwords
- ❌ Customer data
- ❌ Inspection data
- ❌ Photos
- ❌ Personal information

### Compliance:
✅ GDPR compliant (with consent)  
✅ CCPA compliant  
✅ App Store compliant  
✅ No PII collected  

---

## Cost Considerations 💰

### Firebase Free Tier:
- ✅ Unlimited analytics events
- ✅ Unlimited crash reporting
- ✅ Up to 10 GB/month storage
- ✅ Plenty for most apps

### Paid Plans:
- Only needed for very large scale
- Pay-as-you-go
- Typical cost: $0-25/month

---

## Troubleshooting 🔧

### Issue: Pod install fails
```bash
# Update CocoaPods
sudo gem install cocoapods
pod repo update

# Try again
pod install
```

### Issue: Firebase not initializing
```
Check:
1. GoogleService-Info.plist is in project
2. File is in target membership
3. FirebaseApp.configure() is called
4. Imports are correct
```

### Issue: Events not showing in console
```
- Allow 24-48 hours for first data
- Check debug logging is enabled
- Verify app is in foreground
- Check network connection
```

### Issue: Crashlytics symbols not working
```
1. Verify dSYM is enabled
2. Check run script is correct
3. Ensure script runs before compile
4. Upload symbols manually if needed
```

---

## Quick Start Commands 🚀

```bash
# 1. Install CocoaPods (if needed)
sudo gem install cocoapods

# 2. Navigate to project
cd "/Users/egreska/Systems Inspector"

# 3. Install Firebase
pod install

# 4. Open workspace (IMPORTANT!)
open "Systems Inspector.xcworkspace"

# 5. Build and test
# In Xcode: Product → Build (Cmd+B)
```

---

## Analytics Implementation Checklist ✅

### Code Implementation:
- ✅ AnalyticsManager.swift created
- ✅ Event tracking methods defined
- ✅ Integration points added
- ✅ Screen tracking implemented
- ✅ Error tracking implemented
- ✅ Performance tracking added

### Firebase Setup:
- [ ] Create Firebase project
- [ ] Add iOS app to project
- [ ] Download GoogleService-Info.plist
- [ ] Run `pod install`
- [ ] Add GoogleService-Info.plist to Xcode
- [ ] Import Firebase in AppDelegate
- [ ] Call FirebaseApp.configure()
- [ ] Add Crashlytics run script
- [ ] Enable dSYM
- [ ] Uncomment Firebase code in AnalyticsManager
- [ ] Build and test
- [ ] Verify events in Firebase Console

---

## Alternative: AppCenter (Microsoft) 📊

If you prefer AppCenter over Firebase:

### Install AppCenter:
```ruby
# In Podfile
pod 'AppCenter/Analytics'
pod 'AppCenter/Crashes'
```

### Initialize:
```swift
import AppCenter
import AppCenterAnalytics
import AppCenterCrashes

// In AppDelegate
AppCenter.start(
    withAppSecret: "YOUR_APP_SECRET",
    services: [Analytics.self, Crashes.self]
)
```

### Update AnalyticsManager:
```swift
// Replace Firebase calls with AppCenter
Analytics.trackEvent(eventName, withProperties: parameters)
Crashes.trackError(error)
```

---

## Testing Analytics 🧪

### Test Events:
```swift
1. Run app
2. Perform actions:
   - Login
   - Create customer
   - View inspection
   - Take photo
   - Generate report
3. Check console for:
   📊 Analytics Event: login
   📊 Analytics Event: customer_created
   📊 Analytics Event: inspection_viewed
```

### Test Crashlytics:
```swift
// Add temporary test crash
Button("Test Crash") {
    fatalError("Testing Crashlytics")
}

1. Tap button
2. App crashes
3. Relaunch app
4. Check Firebase Console (5-10 min delay)
```

---

## Production Monitoring 📈

### Key Metrics to Track:

**User Engagement:**
- Daily Active Users (DAU)
- Monthly Active Users (MAU)
- Session duration
- Screen views

**Feature Usage:**
- Customers created per day
- Inspections created per day
- Photos uploaded per day
- Reports generated per day

**Performance:**
- Average operation times
- Cache hit rates
- Memory usage trends
- Slow operations

**Stability:**
- Crash-free users rate (target: >99%)
- Top crashes
- Error frequency
- Non-fatal errors

**Security:**
- Failed login attempts
- Account lockouts per day
- Password resets per day
- Security incidents

---

## Dashboard Setup 📊

### Recommended Firebase Dashboards:

**1. User Engagement:**
```
Metrics:
- Active users (DAU/MAU)
- New users
- User retention
- Session length
```

**2. Feature Adoption:**
```
Events:
- customer_created
- inspection_created  
- report_generated
- password_reset
```

**3. Performance:**
```
Events:
- performance_metric
- cache_hit rate
- memory_usage
```

**4. Security:**
```
Events:
- account_locked
- login failures
- password_reset attempts
```

---

## Advanced Features 🚀

### A/B Testing:
```swift
// Use Firebase Remote Config
let config = RemoteConfig.remoteConfig()
let featureEnabled = config["new_feature_enabled"].boolValue

if featureEnabled {
    // Show new feature
}
```

### Push Notifications:
```ruby
# In Podfile
pod 'Firebase/Messaging'
```

### Performance Monitoring:
```swift
let trace = Performance.startTrace(name: "load_customers")
// ... operation ...
trace?.stop()
```

---

## Cost Optimization 💰

### Reduce Firebase Costs:

**1. Sample Analytics (if needed):**
```swift
// Only log 10% of events
if Int.random(in: 1...10) == 1 {
    AnalyticsManager.shared.logEvent(...)
}
```

**2. Limit Custom Parameters:**
```swift
// Avoid high-cardinality values
// Good: category, status, type
// Bad: timestamp, unique IDs, user input
```

**3. Use Event Grouping:**
```swift
// Instead of: "customer_1_viewed", "customer_2_viewed"
// Use: "customer_viewed" with parameters
```

---

## Summary

### What You'll Get:

**Analytics:**
- 📊 Real-time user insights
- 📈 Usage patterns
- 🎯 Feature adoption metrics
- ⚡ Performance monitoring

**Crashlytics:**
- 💥 Automatic crash reporting
- 🐛 Symbolicated stack traces
- 📊 Crash-free users rate
- 🔔 Email alerts on crashes

**Benefits:**
- Understand user behavior
- Find and fix bugs faster
- Improve app performance
- Make data-driven decisions

---

## Next Steps

1. **Create Firebase Project** (10 minutes)
2. **Run `pod install`** (5 minutes)
3. **Add GoogleService-Info.plist** (2 minutes)
4. **Update AppDelegate** (5 minutes)
5. **Update AnalyticsManager** (10 minutes)
6. **Test** (15 minutes)
7. **Deploy** 🚀

**Total Time:** ~1 hour for complete setup

---

**Status:** ✅ Code Ready - Just needs Firebase configuration  
**Effort:** Medium (mostly setup, not coding)  
**Benefit:** High (critical for production apps)

**Ready when you are!** 🔥
