# RooBin commercial payment architecture

Status: implementation baseline  
Decision date: 2 August 2026  
Scope: RooBin Fines Team, GBP 10 per team per season

## Decision

RooBin uses a provider-neutral commercial catalogue and authoritative
team-season entitlement service. The purchase channel changes how payment is
collected, but never changes which backend record grants access.

| Channel | Checkout | Renewal | Server evidence |
|---|---|---|---|
| Web | Stripe-hosted Checkout; Apple Pay is shown by Stripe on eligible devices | Manual next-season purchase initially; automatic only for a separately published recurring offering with explicit consent | Verified Stripe webhook and reconciliation |
| iOS | StoreKit In-App Purchase | Non-renewing team-season purchase initially; restore is mandatory | Verified App Store transaction plus App Store Server API/notifications where supported |
| League invoice | Invoice and bank transfer after approved quote | Manual | Audited settlement by an authorised operator |

Apple Pay is a wallet/payment method, not the entitlement or renewal engine.
It is suitable inside Stripe's web checkout. It must not be used as an
alternative native payment mechanism to unlock RooBin's digital features.
Apple's current guideline 3.1.1 requires In-App Purchase for feature unlocks,
while guideline 3.1.3(b) permits access to purchases made on another platform
when the same item is also available as an in-app purchase. The final native
route must be rechecked immediately before App Review.

Primary references:

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/)
- [Apple subscription billing guidance](https://developer.apple.com/documentation/storekit/handling-subscriptions-billing)
- [Stripe Checkout](https://docs.stripe.com/payments/checkout)
- [Stripe Checkout lifecycle](https://docs.stripe.com/payments/checkout/how-checkout-works)
- [Stripe wallets](https://docs.stripe.com/payments/wallets)

## Why the initial Team offer is non-renewing

A RooBin season is a named playing cycle and may not align to a fixed monthly,
six-monthly or annual billing boundary. Automatically charging against a
calendar interval could pay for the wrong or nonexistent season. The GBP 10
baseline therefore uses a deliberate next-season purchase:

1. the captain creates or imports the upcoming season;
2. RooBin displays the current catalogue price and existing entitlement;
3. the captain purchases that exact team-season;
4. a verified provider event grants access once;
5. reminders target billing contacts, never ordinary players.

The catalogue supports automatic renewal, but it can only be published for an
offering whose billing interval maps unambiguously to the covered service and
whose checkout captures explicit renewal consent.

## Security boundary

- Clients submit team, season and offering identity, never an amount.
- Checkout reloads the current published price from the database.
- Only active team leadership can initiate a Team purchase.
- Redirect/success pages never grant access.
- Provider signatures and unique event IDs protect webhook processing.
- Service-role code writes subscriptions and entitlements; clients have read
  access only to records belonging to their teams.
- Capability checks bind team membership, entitlement state and validity.
- Payment instruments, secrets and full provider payloads are never exposed to
  app clients.

## Expiry baseline

Expired teams retain their data and access to account/privacy journeys. Paid
writes become unavailable after any configured grace period once enforcement
is activated. Historical read access remains available for the initial launch
unless the product owner approves a narrower policy. Renewal restores normal
access without recreating the team, roster or historical seasons.
