# Roo Bin iOS Build Pack

Status: baseline review and build plan  
Reviewed: 31 July 2026  
Source: the `wh-pool-fines` repository at this revision

This directory is the controlling documentation set for building the Roo Bin iOS
application without replacing the existing web application or its Supabase data.

## Documents

1. [IOS_READINESS_REVIEW.md](./IOS_READINESS_REVIEW.md) — what exists, what is
   reusable, and what must be corrected before release.
2. [IOS_PRODUCT_SPEC.md](./IOS_PRODUCT_SPEC.md) — user journeys, screen model,
   feature parity, and experience requirements.
3. [IOS_ARCHITECTURE.md](./IOS_ARCHITECTURE.md) — the recommended native
   architecture and backend/security boundaries.
4. [IOS_BACKLOG.md](./IOS_BACKLOG.md) — sequenced epics and implementation-ready
   user stories.
5. [APP_STORE_CHECKLIST.md](./APP_STORE_CHECKLIST.md) — the living release and
   App Review checklist.
6. [LIVE_SUPABASE_AUDIT_2026-07-30.md](./LIVE_SUPABASE_AUDIT_2026-07-30.md) —
   read-only evidence for IOS-001 and the confirmed production drift.
7. [STAGING_SECURITY_VERIFICATION_2026-07-30.md](./STAGING_SECURITY_VERIFICATION_2026-07-30.md) —
   implementation and test evidence for IOS-006 and IOS-007.
8. [STAGING_UNLOCK_SECURITY_VERIFICATION_2026-07-30.md](./STAGING_UNLOCK_SECURITY_VERIFICATION_2026-07-30.md) —
   server verification, rate-limit, secret-redaction, and grant evidence for
   IOS-008.
9. [STAGING_PROTECTED_MUTATION_VERIFICATION_2026-07-30.md](./STAGING_PROTECTED_MUTATION_VERIFICATION_2026-07-30.md) —
   atomic grant consumption, replay denial, and protected-mutation evidence.
10. [DEPENDENCY_REGISTER.md](./DEPENDENCY_REGISTER.md) — approved native
    dependencies, privacy review, and addition criteria.
11. [BACKEND_CONTRACT.md](./BACKEND_CONTRACT.md) — v1 native/web RPC, Edge
    Function, environment, error, and security contract.
12. [PRIVACY_RETENTION_DRAFT.md](./PRIVACY_RETENTION_DRAFT.md) — data inventory,
    proposed lifecycle and account-deletion baseline.
13. [DEFERRED_ACTIONS.md](./DEFERRED_ACTIONS.md) — owner, desktop, membership,
    external-service, and post-download gates.

## Controlling decisions

- Build a native iPhone application in SwiftUI.
- Keep the existing React/Vite application operational as the web client and
  behavioural reference.
- Keep the existing Supabase project and Postgres database authoritative.
- Use email OTP as the universal fallback; deliver Sign in with Apple and Sign
  in with Google on iOS and web against the same canonical Supabase account.
- Keep the authentication model compatible with future Android Credential
  Manager integration; do not introduce a second identity store.
- Defer WhatsApp/SMS authentication beyond v1.
- Do not ship the web application inside a thin `WKWebView` wrapper.
- Move privileged and protected operations to server-side functions before
  exposing them to the native client.
- Treat the live Supabase schema and policies as unverified until exported and
  compared with the repository migrations.
- Deliver parity in vertical increments, using TestFlight throughout.

## Definition of ready to start iOS implementation

Stories IOS-001 through IOS-012 in the backlog are complete, the live Supabase
policy export has been reviewed, account deletion behaviour has been agreed, and
the product owner has accepted the proposed product specification.
