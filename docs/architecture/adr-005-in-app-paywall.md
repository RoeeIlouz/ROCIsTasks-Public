---
ontology: true
type: decision
domain: monetization
summary: Every platform shows the app's own PaywallScreen (Play via RevenueCat packages, web via Lemon Squeezy), tagged by PaywallSource
status: active
tags: [paywall, revenuecat, analytics, free-trial]
related: [adr-002-server-authoritative-premium]
discovered: 2026-09-25
verified: true
---

# ADR-005: One in-app paywall for all platforms

## Status
Accepted (2026-09-25)

## Context
Android called `RevenueCatUI.presentPaywall()`, but no paywall was configured in RevenueCat,
so users saw RevenueCat's generic fallback: no free-trial copy, no localization, no brand.
Web already used the app's `PaywallScreen` (Lemon Squeezy). There was no funnel data.

## Decision
- `SubscriptionService.showPaywall(source:)` opens `PaywallScreen(source:)` everywhere.
  Android purchases RevenueCat packages (the Play default offer applies the 7-day yearly
  trial); web opens Lemon Squeezy checkout with `checkout[custom][user_id]`.
- The sheet shows the feature that triggered it (`PaywallSource.featureLabel`) and, when
  Play offers it, the trial badge/CTA/terms from `defaultOption.freePhase`.
- `paywall_shown` / `paywall_result` analytics events carry the source; web analytics on.

## Rationale
1. One localized, on-brand paywall that we control in code (8 languages).
2. Trial and feature context are what convert; the fallback showed neither.
3. Measurable per trigger point.

## Trade-offs
- No remote paywall experiments (RevenueCat paywall A/B) without an app update/patch.

## Consequences
- **Positive**: Consistent, localized, measurable paywall; trial visible.
- **Negative**: Copy/design changes need a Shorebird patch.
- **Mitigation**: Dart-only, so patches ship same day.

## Revisit trigger
Wanting server-driven paywall experiments at scale.
