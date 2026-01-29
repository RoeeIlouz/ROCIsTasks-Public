# Deployment Guide for ROCI's Tasks

## 🔐 Security Setup

### 1. Environment Configuration

1. **Copy environment template:**

   ```bash
   cp .env.example .env
   ```

2. **Fill in your Firebase configuration:**
   - Get your Firebase config from [Firebase Console](https://console.firebase.google.com)
   - Replace all placeholder values in `.env`
   - **NEVER commit `.env` to version control**

### 2. Android Release Signing

1. **Generate a release keystore:**

   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```

2. **Create `android/key.properties`:**

   ```bash
   cp android/key.properties.example android/key.properties
   ```

3. **Fill in your keystore details:**

   ```properties
   storePassword=your-store-password
   keyPassword=your-key-password
   keyAlias=upload
   storeFile=/path/to/your/upload-keystore.jks
   ```

4. **Secure your keystore:**
   - Store keystore file in a secure location
   - Back up keystore and passwords securely
   - **NEVER commit keystore or key.properties to version control**

### 3. Firebase Services Setup

1. **Enable required services in Firebase Console:**
   - Authentication (Google Sign-In)
   - Firestore Database
   - Crashlytics
   - Analytics (optional)

2. **Configure Firestore security rules:**

   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /users/{userId}/{document=**} {
         allow read, write: if request.auth != null && request.auth.uid == userId;
       }
     }
   }
   ```

3. **Download configuration files:**
   - `google-services.json` for Android
   - `GoogleService-Info.plist` for iOS
   - Place in respective platform directories

## 🚀 Build and Deploy

### Prerequisites

```bash
flutter doctor
flutter pub get
```

### Android Deployment

1. **Debug build:**

   ```bash
   flutter build apk --debug
   ```

2. **Release build:**

   ```bash
   flutter build apk --release
   ```

3. **App Bundle (recommended for Play Store):**
   ```bash
   flutter build appbundle --release
   ```

### iOS Deployment

1. **Build for iOS:**

   ```bash
   flutter build ios --release
   ```

2. **Archive in Xcode:**
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select "Any iOS Device" as target
   - Product → Archive
   - Upload to App Store Connect

### Web Deployment

1. **Build for web:**

   ```bash
   flutter build web --release
   ```

2. **Deploy to hosting service:**
   - Firebase Hosting
   - Netlify
   - Vercel
   - GitHub Pages

## 📊 Monitoring Setup

### 1. Firebase Crashlytics

Crashlytics is automatically configured when you build with the proper Firebase setup. Monitor crashes at:

- [Firebase Console → Crashlytics](https://console.firebase.google.com)

### 2. Firebase Analytics

Track user behavior and app performance:

- [Firebase Console → Analytics](https://console.firebase.google.com)

### 3. Performance Monitoring

Monitor app performance metrics:

- App startup time
- Screen rendering performance
- Network request performance

## 🔍 Testing Before Release

### 1. Automated Testing

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Analyze code quality
flutter analyze
```

### 2. Manual Testing Checklist

- [V] App launches without crashes
- [V] User can sign in with Google
- [V] Tasks can be created, edited, deleted
- [V] Offline functionality works
- [V] Data syncs when back online
- [V] Notifications work properly
- [V] Home widgets update correctly
- [V] App works on different screen sizes
- [V] Dark mode functions properly
- [V] Localization works (English/Hebrew)

### 3. Performance Testing

- [ ] App startup time < 3 seconds
- [V] Smooth scrolling in task lists
- [ ] No memory leaks during extended use
- [ ] Battery usage is reasonable
- [ ] Network usage is optimized

## 🚨 Emergency Procedures

### Rollback Plan

1. **Immediate response:**
   - Monitor crash reports and user feedback
   - Identify critical issues within 2 hours

2. **Hotfix deployment:**
   - Create hotfix branch from last stable release
   - Implement minimal fix
   - Fast-track testing (< 4 hours)
   - Deploy emergency update

3. **Communication:**
   - Notify users of known issues
   - Provide timeline for fix
   - Update app store descriptions if needed

### Critical Issue Response

1. **Severity 1 (App crashes, data loss):**
   - Response time: < 1 hour
   - Fix deployment: < 8 hours

2. **Severity 2 (Major feature broken):**
   - Response time: < 4 hours
   - Fix deployment: < 24 hours

3. **Severity 3 (Minor issues):**
   - Response time: < 24 hours
   - Fix deployment: Next regular release

## 📈 Post-Launch Monitoring

### Key Metrics to Track

1. **Technical Metrics:**
   - Crash rate (target: < 0.1%)
   - App startup time (target: < 3s)
   - API response times
   - Sync success rate (target: > 99%)

2. **User Metrics:**
   - Daily/Monthly Active Users
   - User retention (Day 1, 7, 30)
   - Feature adoption rates
   - User satisfaction scores

3. **Business Metrics:**
   - Conversion rate (free to premium)
   - Revenue per user
   - Churn rate
   - Support ticket volume

### Monitoring Tools

- **Firebase Console:** Crashlytics, Analytics, Performance
- **Google Play Console:** Android app metrics
- **App Store Connect:** iOS app metrics
- **Custom dashboards:** For business metrics

## 🔄 Continuous Deployment

### CI/CD Pipeline

1. **Code commit triggers:**
   - Automated testing
   - Code quality checks
   - Security scans

2. **Release process:**
   - Automated builds
   - Staging deployment
   - Production deployment (with approval)

3. **Monitoring:**
   - Automated alerts for issues
   - Performance regression detection
   - User feedback collection

### Release Schedule

- **Major releases:** Monthly
- **Minor updates:** Bi-weekly
- **Hotfixes:** As needed (within 24 hours)
- **Security updates:** Immediate

## 📞 Support and Maintenance

### Support Channels

- In-app feedback system
- Email support
- App store reviews monitoring
- Social media monitoring

### Maintenance Tasks

- **Weekly:** Review crash reports and user feedback
- **Monthly:** Performance optimization review
- **Quarterly:** Security audit and dependency updates
- **Annually:** Major feature planning and architecture review

---

**Remember:** Always test thoroughly before deploying to production, and have a rollback plan ready!
