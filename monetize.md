# ROCI's Tasks - Monetization Strategy

## Overview

This document outlines the subscription-based monetization strategy for ROCI's Tasks, a student-focused task management app.

---

## Premium Features to Gate

### High-Value Features (Difficulty: Low-Medium)

| Feature | Why Premium? | Implementation Difficulty |
|---------|-------------|---------------------------|
| **Unlimited categories** | Free: 5 max | Easy - add counter check |
| **Subtasks** | High value for complex tasks | Medium - new data model + UI |
| **Recurring tasks** | Power user feature | Medium - scheduling logic needed |
| **Task templates** | Saves time for repetitive tasks | Easy - copy task feature |
| **All widget types** | Free: 1 widget type | Easy - check in widget provider |
| **Calendar overlays** | Show all calendars simultaneously | Medium - foundation exists |
| **Smart notifications** | Location-based, smart snooze | Medium - permissions + logic |
| **Task attachments** | Add files/images to tasks | Medium - Firebase Storage |

---

## Free Tier (to drive adoption)

- Basic task CRUD (Create, Read, Update, Delete)
- 5 categories maximum
- Google Calendar view
- Basic notifications
- Dark mode
- 1 widget type (Task Widget)

---

## Implementation Difficulty

### Easy Features (1-2 days each)
- Category limit: Add `if (categoryCount >= 5 && !isPremium) showPaywall()`
- Widget limit: Same check in widget provider
- Templates: Clone task functionality

### Medium Features (3-5 days each)
- Subtasks: New Firestore subcollection, nested UI
- Recurring tasks: Need background job scheduler
- Attachments: Firebase Storage integration + picker

### Foundation Work (One-time: 2-3 days)
- Subscription state management (Provider/Riverpod)
- Paywall UI screens
- RevenueCat or similar for payments

---

## Pricing Recommendation

For a **student audience**, pricing should be affordable:

| Model | Price | Best For |
|-------|-------|----------|
| **Monthly** | $1.99 - $2.99/month | Flexibility |
| **Yearly** | $14.99 - $19.99/year | Best value (~60% off) |
| **Lifetime** | $39.99 - $49.99 once | Power users |

### Recommendation: $1.99/month or $14.99/year

### Pricing Rationale

- Students are price-sensitive
- Todoist Premium is $5/month, Todoist Student is free with .edu email
- Competitors:
  - Microsoft To Do: Free
  - TickTick: $3/month
  - Things: $10/month (one-time)
- Unique ROCIs integration justifies slight premium over generic apps

### Alternative: Freemium with Ads

- Free with banner ads at bottom
- $0.99/month to remove ads + basic premium
- $2.99/month for full premium

---

## Implementation Roadmap

### Phase 1 (1 week) - Quick Launch
- Implement category limit (5 free, unlimited premium)
- Build paywall UI screens
- Integrate RevenueCat for payments

### Phase 2 (1 week) - Widget & Templates
- Widget limit (1 free, all premium)
- Task templates feature

### Phase 3 (2-3 weeks) - Advanced Features
- Subtasks
- Recurring tasks
- Task attachments

---

## Technical Considerations

### Required Dependencies
```yaml
# pubspec.yaml
dependencies:
  revenue_cat: # or purchaser
  flutter_riverpod: # subscription state management
```

### Data Model Changes
```dart
class SubscriptionStatus {
  final bool isPremium;
  final DateTime? expiryDate;
  final String tier; // free, premium, lifetime
}
```

### Paywall Triggers
- Attempting to create 6th category
- Attempting to add 2nd widget type
- Attempting to create subtask
- Attempting to set recurrence
- Attempting to add attachment

---

## Next Steps

1. Design paywall UI screens
2. Set up RevenueCat account
3. Implement subscription state management
4. Build category limit feature
5. Test payment flow
6. Launch to beta testers
