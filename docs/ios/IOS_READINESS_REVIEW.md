# iOS Readiness Review

Status: complete repository review; live-service verification outstanding  
Reviewed: 31 July 2026

## Executive assessment

Roo Bin is suitable for a native iOS client while retaining the existing
Supabase database. The domain is already separated into reusable JavaScript
modules and a relational data model, but the current client is also responsible
for several security-sensitive decisions. A direct screen-by-screen port would
preserve those weaknesses and is not App Store ready.

The recommended path is:

1. Stabilise and verify the shared backend contract.
2. Move privileged mutations, unlock-code verification, invitation acceptance,
   identity linking, bulk import, and account deletion behind server-controlled
   endpoints or Supabase database/Edge functions.
3. Build a native SwiftUI client against that contract.
4. Keep the web client working against the same backend.
5. release through internal and external TestFlight before App Review.

There is no need to migrate user or team data into a second database.

## Review scope and evidence

Reviewed:

- React application composition and all visible feature components.
- Supabase client, authentication, data access, membership, permission, audit,
  invite, image, RackEm, and profile modules.
- `supabase/schema.sql`, generated database types, and all repository migrations.
- Vercel RackEm proxy and server-side scraper.
- package, environment, hosting, and repository documentation.
- current Apple App Review, privacy, privacy-manifest, account-deletion, HIG, and
  submission requirements from official Apple sources.

Not verified in this review:

- the schema, functions, grants, RLS policies, storage policies, or migration
  history actually deployed in the live Supabase project;
- Supabase Auth settings, OTP expiry/rate limits, SMTP configuration, redirect
  allow-list, or production key rotation;
- Vercel production environment variables and function protections;
- Twilio or team-email endpoint implementations;
- live privacy policy, support site, domain ownership, Apple Developer account,
  bundle identifier, certificates, or App Store Connect record;
- the current production deployment and its complete user behaviour.

These are explicit discovery stories in the backlog, not assumed facts.

## Current product inventory

### Identity and onboarding

- Email OTP registration and sign-in through Supabase Auth.
- Optional WhatsApp OTP through separately configured endpoints.
- Player creation and linking to an authenticated Supabase user.
- Profile editing, preferred authentication method, and team-notification choice.
- Create team, join by join code, switch team, and multiple team memberships.

### Team roles and administration

- Captain, vice-captain, and member team roles.
- Platform administrator compatibility role.
- Player roster and profile administration.
- Invite creation, resend, revoke, and placeholder email-delivery behaviour.
- Captain transfer and member removal.
- Team settings for subs, drivers, amount, branding, and RackEm connection.
- Team unlock-code setup, change, recovery, and platform-admin reset flows.

### Pool operations

- Dashboard totals, balances, leaderboard information, and season filtering.
- Per-user, per-team dashboard season preference.
- Match creation and editing with date, competition/season, venue, opponent,
  participating players, and drivers.
- Fine recording by player and fine type.
- Subs calculation with configurable amount and driver exemption.
- Match submission and protected reopening.
- Fine/sub paid and unpaid tracking.
- Team-scoped fine-type and season management.
- RackEm league/team selection, fixture import, and refresh.

### Data and media

- Team logo upload to a public Supabase Storage bucket.
- Client-side logo resize to 1200 × 400 WebP.
- Historic player and fine names copied onto fine/sub records.
- Audit events for selected security and destructive operations.
- JSON bulk import logic remains in the data module.

## Current architecture

| Concern | Current implementation | iOS implication |
|---|---|---|
| UI | React 18, Vite, Tailwind | Rebuild natively in SwiftUI |
| Hosting | Vercel SPA | Retain for web client |
| Database | Supabase Postgres | Retain as system of record |
| Authentication | Supabase email OTP; optional WhatsApp OTP | Retain email OTP; add Apple and Google through Supabase; defer WhatsApp/SMS from native v1 |
| Authorisation | RLS plus JavaScript permission checks | RLS/server must become authoritative |
| Media | Public Supabase Storage bucket | Reassess public exposure; use native image pipeline |
| External data | Vercel proxy scrapes RackEm HTML | Keep behind controlled backend contract |
| Local state | browser local storage | Keychain for credentials; app storage only for non-secrets |
| Audit | client-issued inserts into `audit_logs` | Privileged backend should emit authoritative audit events |

## Security and release findings

Severity meanings:

- P0: blocks safe production/App Store release.
- P1: must be resolved before external TestFlight.
- P2: should be resolved before first public release.
- P3: documentation or maintainability improvement.

### P0 — canonical schema contains permissive policies

`supabase/schema.sql` creates `allow all` policies on core and team tables.
The later fix-forward migration removes these policies and installs team-aware
ones, but running the README’s instruction to apply `schema.sql` alone would
create an unsafe database.

Required action:

- export the live schema and policy catalogue;
- make migrations the sole reproducible source of truth or regenerate a safe
  baseline schema;
- add automated policy tests for anonymous, member, vice-captain, captain,
  removed member, and platform-admin contexts.

### P0 — RLS does not enforce application roles for many writes

The fix-forward policies allow any active team member to write matches, fines,
subs, seasons, and fine types. The React client restricts these actions to team
leaders, but a client is not a security boundary. Team-invite writes are also
member-scoped rather than leader-scoped in the fix-forward migration.

Required action:

- encode role-specific write permission in RLS or privileged RPC/Edge functions;
- deny direct table mutations for protected workflows;
- test cross-team identifiers and removed memberships.

### P0 — unlock-code verification and throttling occur on the client

The client fetches unlock hash metadata, derives the candidate hash locally, and
stores attempt counters in local storage. A modified client can bypass local
rate limits and attempt protected database mutations directly. A native port
must not reproduce this design.

Required action:

- make verification a server-side function;
- store only the hash server-side and do not return it or its salt to clients;
- apply durable, server-side rate limiting and security logging;
- issue a short-lived, single-purpose authorisation result or perform the
  protected mutation atomically in the same function.

### P0 — account deletion is absent

The app creates accounts but has no in-app complete-account deletion journey.
Apple requires apps supporting account creation to let users initiate deletion
inside the app. Deletion semantics are non-trivial because a player may own
teams and historical fines reference players.

Required action:

- agree retention/anonymisation rules;
- provide reauthentication and clear impact preview;
- transfer or resolve sole captaincy;
- delete the Supabase Auth user and personal data server-side;
- remove or anonymise uploaded/personal content as appropriate;
- preserve only records that have a documented lawful/product reason;
- provide status and completion handling.

### P1 — identity registration and linking are exposed to race/abuse risks

Anonymous player lookup is intentionally broad to support pre-auth checks, and
anonymous registration can create unlinked player records. Identity is
represented by both `players.user_id` and deprecated `auth_user_id`. The client
then attaches the authenticated user to a player.

Required action:

- replace pre-auth player enumeration with a non-enumerating server workflow;
- create/link the player after verified authentication in one transaction;
- converge on `players.user_id`;
- prevent account takeover through email/mobile collision and concurrent linking;
- return generic sign-in responses where enumeration would leak membership.

### P1 — privileged flows are multi-call and non-atomic

Match updates delete and recreate player, fine, and sub child records across
several requests. Captain transfer updates two memberships separately. Protected
deletion writes the audit entry after deletion and deliberately ignores audit
failures. Bulk import deletes whole tables without team scoping.

Required action:

- implement transactional RPCs for aggregate save and privileged actions;
- make audit creation part of the protected transaction;
- remove or redesign bulk import as team-scoped, validated, privileged,
  backed-up, and asynchronous if large;
- add idempotency for retryable native requests.

### P1 — hard-coded legacy admin PIN and stale documentation

`ADMIN_PIN = '1234'` remains exported in `src/App.jsx` and the README directs
operators to change it in source. Current protected flows appear to use the team
unlock-code design, but the constant and instructions must be removed so they
cannot be mistaken for a security control.

Required action: confirm it is unused, delete it, and update the README.

### P1 — notification endpoints accept sensitive client payloads

Client-configured endpoints receive OTP, invitation, recipient, or generated
unlock-code data. Their implementation and authentication are not present here.
A public endpoint must not trust actor, team, recipient, or role data supplied
by the client.

Required action:

- authenticate with the Supabase access token;
- resolve actor, team, recipients, and permission server-side;
- enforce rate limits and replay protection;
- never log OTPs, invite tokens, or unlock codes;
- document processors and retention for privacy disclosure.

### P1 — public logo storage and file lifecycle need review

Team logos are placed in a public bucket. Storage write policy is role-aware in
the latest logo migration, but public URLs are permanent and deletion/lifecycle
behaviour is not implemented. WebP-only output also differs from the earlier
mobile JPEG behaviour described in project history.

Required action:

- decide whether public team logos are intended;
- validate file signatures, decoded dimensions, and output size server-side;
- strip metadata in the native image pipeline;
- replace/delete prior objects and delete them with the team/account;
- test HEIC/HEIF input from iPhone and document the canonical output format.

### P1 — RackEm integration is an external dependency without a stable contract

The app depends on a server-side HTML scraper and stores third-party URLs and
fixture data. Markup, availability, permission, rate limits, and content rights
can change.

Required action:

- confirm permitted use and branding;
- isolate parsing behind a versioned backend endpoint;
- add timeouts, caching, observability, and graceful stale-data behaviour;
- ensure the app remains usable when RackEm is unavailable.

### P2 — privacy, support, and consent artefacts are not present

No in-app privacy policy, retention policy, privacy choices flow, or support
route is present in the repository. App Store privacy answers must include
Supabase, Twilio/email processors, RackEm calls, and any future diagnostics.

### P2 — accessibility is not verified

The mobile web UI has many emoji icons, compact controls, colour-coded states,
custom modals, and horizontally dense administration screens. Native parity
must preserve capability, not those exact interaction patterns.

Required action: define semantic labels, Dynamic Type behaviour, VoiceOver
order, sufficient contrast, 44-point targets, Reduce Motion behaviour, keyboard
support where applicable, and non-colour status cues.

### P2 — no automated quality gates

`package.json` contains build, development, and preview scripts only. There is
no lint, unit, integration, policy, end-to-end, accessibility, or security test
command. The repository build could not be run during this review because local
dependencies were not installed (`vite: command not found`).

### P2 — generated database types appear incomplete

`supabase/database.types.ts` does not visibly cover the complete evolved domain.
Generate types from the verified live schema and use them for both the web
contract and native API modelling.

### P3 — repository hygiene

`src/App.jsx.save` is a stale source copy and creates ambiguity. The README
schema inventory and project structure no longer describe the current product.

## Apple-specific assessment

The reviewed web baseline originally used the developer’s own email OTP system,
so Apple Guideline 4.8 did not force Sign in with Apple at that point. The
31 July product decision adds Google authentication to iOS and web, so native
Sign in with Apple is now a v1 requirement and Guideline 4.8 must be checked
again against the final implementation at submission. Apple authentication will
also be offered on the web; email OTP remains the universal fallback.

The app’s account-based functionality is significant, so requiring login is
defensible. App Review must receive a stable demo account or approved,
fully-featured demo mode, live backend access, team data, and explanations for
role-locked actions.

As of this review date, Apple states that uploads must be built with Xcode 26 or
later using the iOS 26 SDK or later. The deployment target can be older and
should be selected separately based on the supported-device decision.

Official sources:

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Offering account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)
- [Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)

## Go/no-go conclusion

Go for native product development after the P0 backend stories are designed and
the live deployment has been exported. Do not submit to external TestFlight or
App Review while any P0 item remains open. UI prototyping and the native project
foundation may proceed in parallel with backend hardening, but native production
writes must use the hardened contract.
