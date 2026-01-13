# Firebase Initialization Troubleshooting Guide

## 🚨 Issue: "[core/no-app] No Firebase App '[DEFAULT]' has been created"

This error occurs when Firebase fails to initialize properly. Here's how to diagnose and fix it:

---

## 🔍 **STEP 1: Quick Diagnosis**

Run this command to test your Firebase configuration:

```bash
dart run scripts/test_firebase.dart
```

This will check if your `.env` file is properly configured.

---

## 🛠️ **STEP 2: Common Fixes**

### **Fix 1: Verify .env File Exists**

Make sure you have a `.env` file in your project root:

```bash
# Check if .env exists
ls -la .env

# If missing, copy from template
cp .env.example .env
```

### **Fix 2: Validate .env Content**

Your `.env` file should contain these required variables:

```env
FIREBASE_PROJECT_ID=rocis-todo
FIREBASE_ANDROID_API_KEY=AIzaSyBD5Dw_v-PeYj0qgsnQHG4wYw4VEbfLD9E
FIREBASE_ANDROID_APP_ID=1:867477199658:android:b1183bdcc779788a8d1c53
FIREBASE_WEB_MESSAGING_SENDER_ID=867477199658
FIREBASE_WEB_STORAGE_BUCKET=rocis-todo.firebasestorage.app
```

### **Fix 3: Clean and Rebuild**

```bash
# Clean build cache
flutter clean

# Get dependencies
flutter pub get

# Rebuild
flutter build apk --debug
```

### **Fix 4: Check pubspec.yaml Dependencies**

Ensure these packages are in your `pubspec.yaml`:

```yaml
dependencies:
  firebase_core: ^2.24.2
  flutter_dotenv: ^5.1.0
```

---

## 🔧 **STEP 3: Advanced Troubleshooting**

### **Enable Debug Logging**

The app now includes comprehensive Firebase debug logging. When you run the app in debug mode, you'll see detailed information about:

- Environment variable loading
- Firebase configuration selection
- Initialization process

Look for these debug messages in your console:

```
=== FIREBASE DEBUG INFO ===
Environment variables loaded: true
FIREBASE_PROJECT_ID: rocis-todo
Firebase config project ID: rocis-todo
Firebase config validation: true
Using environment Firebase configuration
Firebase initialized successfully
=== END FIREBASE DEBUG ===
```

### **Test Configuration Manually**

You can test the Firebase configuration without running the full app:

```dart
// Add this to your main.dart temporarily for testing
import 'package:rocis_tasks/core/utils/firebase_debug.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment
  await dotenv.load(fileName: ".env");
  
  // Test configuration
  FirebaseDebug.printDebugInfo();
  final isValid = await FirebaseDebug.testFirebaseConfig();
  print('Configuration valid: $isValid');
  
  // Continue with normal app initialization...
}
```

---

## 🎯 **STEP 4: Fallback Solutions**

### **Solution A: Force Default Configuration**

If environment variables are causing issues, you can temporarily force the app to use default Firebase configuration:

1. Rename your `.env` file to `.env.backup`
2. Run the app - it will use the hardcoded Firebase configuration
3. If it works, there's an issue with your `.env` file

### **Solution B: Verify Firebase Project**

Make sure your Firebase project is active:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `rocis-todo`
3. Ensure the project is active and not suspended

### **Solution C: Regenerate Firebase Configuration**

If all else fails, regenerate the Firebase configuration:

```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase (this will overwrite firebase_options.dart)
flutterfire configure
```

---

## 📱 **STEP 5: Device-Specific Issues**

### **Android Issues**

1. **Check Gradle Build**: Ensure the Android build completes successfully
2. **Verify Package Name**: Make sure your app's package name matches Firebase configuration
3. **Clear App Data**: Uninstall and reinstall the app

### **Network Issues**

1. **Check Internet Connection**: Firebase needs internet for initial setup
2. **Firewall/Proxy**: Ensure Firebase domains aren't blocked
3. **VPN**: Try disabling VPN if active

---

## 🔍 **STEP 6: Debug Information Collection**

If the issue persists, collect this information:

1. **Flutter Version**: `flutter --version`
2. **Device Info**: Android version, device model
3. **Console Output**: Full debug output from app startup
4. **Build Output**: Any errors during `flutter build apk`

### **Enable Verbose Logging**

Run with verbose logging to get more details:

```bash
flutter run --verbose
```

---

## ✅ **Expected Behavior**

When working correctly, you should see:

1. **Console Output**:
   ```
   Environment variables loaded successfully
   Firebase Project ID: rocis-todo
   Using environment Firebase configuration
   Firebase initialized successfully
   ```

2. **App Behavior**:
   - App starts without error screen
   - Login screen appears
   - No Firebase-related crashes

---

## 🆘 **Still Having Issues?**

If none of these solutions work:

1. **Check Firebase Status**: Visit [Firebase Status Page](https://status.firebase.google.com/)
2. **Update Dependencies**: Run `flutter pub upgrade`
3. **Try Different Device**: Test on another device/emulator
4. **Contact Support**: Provide the debug output and steps you've tried

---

## 📋 **Quick Checklist**

- [ ] `.env` file exists and contains required variables
- [ ] `flutter clean && flutter pub get` completed
- [ ] App builds successfully (`flutter build apk --debug`)
- [ ] Firebase project is active in console
- [ ] Internet connection is working
- [ ] No firewall/proxy blocking Firebase domains

---

**Most Common Solution**: The issue is usually a missing or incorrectly formatted `.env` file. Make sure it exists and contains all required Firebase configuration variables.