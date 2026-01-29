# ROCIs-Schedule Integration Setup Guide

## Overview
The ROCIs-tasks app can now display schedule data (courses, lectures, assignments) from the ROCIs-Schedule app. This integration uses **email-based lookup** to find the user's data across Firebase projects.

## How It Works
1. When you sign in to ROCIs-tasks with Google, your email is used to look up your data in the ROCIs-Schedule Firestore database
2. The Firestore security rules allow reading data when the authenticated user's email matches the email stored in the user document
3. Schedule events and assignments appear in the calendar page and home screen widgets

## Required Setup

### Step 1: Deploy Firestore Security Rules

The ROCIs-Schedule Firestore rules need to be updated to allow email-based cross-app access:

```bash
cd ROCIs-Schedule
firebase deploy --only firestore:rules
```

Or manually update the rules in Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com/) → rocis-schedule project
2. Navigate to Firestore Database → Rules
3. The rules should allow reads when `request.auth.token.email` matches the user's email field

### Step 2: Ensure User Email is Stored

The ROCIs-Schedule app must store the user's email in their user document. This is already done during profile setup:
- Path: `users/{userId}`
- Field: `email`

### Step 3: Use Same Google Account

For the integration to work, you must:
1. Sign in to ROCIs-Schedule with your Google account
2. Sign in to ROCIs-tasks with the **same** Google account

## Testing the Integration

1. Install the updated ROCIs-tasks APK
2. Sign in with the same Google account used in ROCIs-Schedule
3. Go to the Calendar page
4. You should see:
   - **Purple cards**: Schedule events (classes, labs, exams) from ROCIs-Schedule
   - **Orange cards**: Assignments from ROCIs-Schedule
   - **Blue cards**: Device calendar events
   - **Task tiles**: Tasks from ROCIs-tasks

## Troubleshooting

### Schedule data not appearing?

1. **Check email match**: Ensure you're signed in with the same Google account in both apps
2. **Check Firestore rules**: Make sure the updated rules are deployed
3. **Check data exists**: Verify you have courses/events/assignments in ROCIs-Schedule
4. **Check debug logs**: Run `flutter run` and look for:
   - `ScheduleFirestoreService: Looking up user by email: your@email.com`
   - `ScheduleFirestoreService: Found user ID: xxx`
   - `CalendarProvider: Loaded X schedule events`

### Common Issues

1. **"No user found with email"**: The email in ROCIs-Schedule doesn't match your Google account email
2. **Permission denied**: Firestore rules haven't been deployed
3. **Empty results**: No schedule data exists for the date range being queried

## Technical Details

- **Cross-app access method**: Email-based lookup (no secondary Firebase auth needed)
- **Data flow**: ROCIs-tasks → Firestore query by email → Get user document ID → Fetch subcollections
- **Collections accessed**: `users/{userId}/courses`, `users/{userId}/events`, `users/{userId}/assignments`
- **Security**: Only authenticated users can read data, and only if their email matches the document's email field
