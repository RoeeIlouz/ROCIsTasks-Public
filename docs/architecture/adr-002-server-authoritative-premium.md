---
ontology: true
type: decision
domain: monetization
summary: Pro status is computed only by Cloud Functions from RevenueCat and Lemon Squeezy; clients cannot write billing fields
status: active
tags: [billing, revenuecat, lemon-squeezy, firestore-rules, security]
related: [adr-005-in-app-paywall, adr-001-last-write-wins-sync]
discovered: 2026-09-25
verified: true
---

# ADR-002: Server-authoritative premium entitlements

## Status
Accepted (2026-09-25)

## Context
Android sells Pro through Google Play (RevenueCat); web sells it through Lemon Squeezy.
Web reads `users/{uid}.is_premium`. Before this decision:
- the app itself wrote `is_premium: true` after a RevenueCat purchase, and Firestore rules let
  any signed-in user write their own user document, so anyone could grant themselves Pro;
- the Lemon Squeezy webhook had never been deployed, and its logic ignored trials
  (`on_trial`), revoked cancelled-but-paid subscriptions and let order/invoice events
  overwrite the flag (lifetime never granted);
- one source could erase the other (a web trial expiring removed Android Pro).

## Decision
- Cloud Functions (`functions/index.js`, Node 22, App Engine service account) own billing:
  - `lemonSqueezyWebhook` (HMAC-verified) sets `ls_subscription_active` (on_trial, active,
    past_due; cancelled until `ends_at`) and `ls_lifetime` (lifetime orders).
  - `revenueCatWebhook` (shared Authorization secret) and `syncPremium` (Firebase ID token,
    called by the app) re-read entitlements from the RevenueCat v2 API (read-only key) and
    set `rc_premium`.
  - `is_premium = ls_subscription_active || ls_lifetime || rc_premium`, computed in a
    transaction by `applyEntitlements`.
- `firestore.rules`: owners may not create/update any billing field on their user doc.
- The app never writes billing fields; it calls `syncPremium` after sign-in and purchases.

## Rationale
1. Revenue integrity: entitlement must not be client-writable.
2. Each payment source is tracked independently, so they can't overwrite each other.
3. Webhook payloads are not trusted for RevenueCat; the entitlement is re-read from the API.

## Trade-offs
- Requires the Blaze plan and three deployed functions (operational surface, secrets in
  `functions/.env`).
- Web Pro depends on webhooks arriving (retries are handled by the providers).
- RevenueCat v2 key only lists entitlement ids, so "any active entitlement = Pro"
  (optional `REVENUECAT_ENTITLEMENT_ID` narrows it).

## Consequences
- **Positive**: No self-granted Pro; trials and lifetime work on web; sources independent.
- **Negative**: A billing change requires a functions deploy.
- **Mitigation**: Function logs print the decision per event; rules verified with a
  throwaway account (403 on billing writes).

## Revisit trigger
A second paid product/entitlement, or moving web checkout to RevenueCat Web Billing.
