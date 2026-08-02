# iOS Architecture

Status: recommended target architecture  
Reviewed: 31 July 2026

## Architecture decision

Build a native SwiftUI application using the Supabase Swift SDK and a hardened,
versioned backend contract. Continue operating React/Vite as a separate client.

### Why native SwiftUI

- Best alignment with Apple interaction, accessibility, privacy, security, and
  review expectations.
- Direct support for Keychain, Authentication Services, PhotosPicker, native
  navigation, Dynamic Type, VoiceOver, and XCTest.
- The product is form-, list-, and workflow-heavy rather than dependent on a
  complex shared rendering engine.
- Existing JavaScript UI code cannot be reused in React Native without a major
  rewrite anyway; the database and behaviour are the valuable shared assets.

### Rejected baseline options

- `WKWebView` wrapper: limited native value, weaker UX/accessibility, and retains
  client security issues.
- Separate iOS database: creates sync, identity, audit, and consistency risk.
- Immediate broad cross-platform rewrite: adds framework risk before the shared
  backend contract is secure.

## System context

```text
SwiftUI iOS client ─┐
                    ├─ Supabase Auth (email OTP, Apple, Google)
React web client ───┤
Future Android app ─┘
                    ├─ Versioned RPC / Edge Function API
                    ├─ Postgres + RLS
                    └─ Supabase Storage

Backend integration service ─ RackEm upstream
Backend notification service ─ Email provider
```

Clients may read team-scoped projections allowed by RLS. Sensitive or aggregate
mutations go through server-owned functions that validate identity, membership,
role, input, rate limits, and idempotency and then write data plus audit events
transactionally.

## Proposed repository layout

Keep the native project in the same repository initially:

```text
ios/
  RooBin.xcodeproj
  RooBin/
    App/
    Core/
      API/
      Auth/
      Persistence/
      Security/
      DesignSystem/
    Features/
      Authentication/
      TeamOnboarding/
      Home/
      Matches/
      Fines/
      TeamManagement/
      Profile/
      PrivacyAccount/
    Resources/
      Assets.xcassets/
      Localizable.xcstrings
      PrivacyInfo.xcprivacy
  RooBinTests/
  RooBinUITests/
docs/ios/
supabase/
src/
```

The initial Xcode project may be created for unsigned Simulator builds after the
bundle identifier, deployment target, and product display name are confirmed.
Do not configure distribution signing, Sign in with Apple, TestFlight, or App
Store capabilities until the Apple Developer membership and actual Team ID are
confirmed.

The approved initial target is iOS 17 on iPhone. Layouts are portrait-first but
must remain usable in landscape. Native iPad layouts are deferred from v1.

## iOS application structure

### Presentation

- SwiftUI views use small feature-specific view models.
- `TabView` owns the four primary areas.
- `NavigationStack` owns typed feature routes.
- Sheets model create/edit/select flows.
- A shared design system defines brand tokens and reusable states without
  replacing standard controls unnecessarily.

### State

- One observable `AppSession` represents authentication and selected team.
- Feature repositories expose async operations and immutable domain models.
- Views do not query Supabase directly.
- Team selection is persisted as a non-secret preference, validated against
  active memberships on every session restore.
- Auth tokens use the Supabase SDK’s supported secure-session mechanism; verify
  its storage implementation and use Keychain for any custom secret material.

### Concurrency

- Use Swift structured concurrency (`async/await`).
- UI-facing observable state is main-actor isolated.
- Support cancellation when screens disappear or team scope changes.
- Mutations use server-issued idempotency keys where retry could duplicate data.

### Dependency management

- Prefer Swift Package Manager.
- Pin direct dependencies intentionally and review every transitive SDK for
  privacy manifest, signature, maintenance, and data collection.
- Initial dependency budget: Supabase Swift plus Apple frameworks. Avoid adding
  analytics, crash, image, or networking frameworks without a recorded decision.

## Shared backend contract

Create a versioned API/RPC catalogue before native feature work:

### Identity

- `complete_authenticated_profile`
- `change_verified_email`
- `change_verified_mobile`
- `delete_account`

### Teams

- `create_team`
- `join_team`
- `accept_team_invite`
- `update_team_settings`
- `change_member_role`
- `transfer_captaincy`
- `remove_team_member`

### Matches and money

- `save_match_aggregate`
- `submit_match`
- `perform_protected_match_action`
- `set_payment_status`
- `manage_fine_type`
- `manage_season`

### Security

- `set_team_unlock_code`
- `change_team_unlock_code`
- `recover_team_unlock_code`
- `perform_protected_action`

### Integrations

- `get_rackem_catalogue`
- `import_rackem_season`
- `refresh_rackem_season`

Names are provisional. Each operation must define request/response schema,
required role, error codes, idempotency, audit event, and transaction boundary.

## Database strategy

- Supabase Postgres remains authoritative.
- Export the live schema before changing migrations.
- Produce a safe baseline migration; do not use the existing permissive
  `schema.sql` for new environments.
- Converge identity on `players.user_id`.
- Make team ownership non-null where the domain requires it.
- Add indexes and constraints only after checking live data.
- Preserve historic fine/sub labels and applied monetary values.
- Use database functions for atomic aggregate writes.
- Add a server-maintained schema/API version so old clients can fail gracefully
  when a breaking migration is unavoidable.

## Authorisation model

### Server is authoritative

Every request derives `auth.uid()` from the verified access token. Client-sent
role, membership, player ID, team ID, actor context, or platform-admin flags are
never trusted without server resolution.

### RLS principles

- Default deny.
- Read only for active team members, with narrowly documented platform support.
- Member self-profile updates are field-limited.
- Operational writes require captain/vice-captain roles.
- Role/captain writes require captain or narrowly scoped support operation.
- Protected/destructive writes are available only through security-definer
  functions with fixed `search_path`, revoked public execution, explicit grants,
  input validation, and audit.
- Removed/invited memberships cannot read team data unless an invite-specific
  function permits the minimum required data.

### Unlock code

- Never return hash, salt, attempt counters, or comparison result detail.
- Verify on the server with a modern password-hashing/KDF choice supported by
  the backend and reviewed parameters.
- Rate limit by user, team, device/network signals where lawful, and time window.
- Prefer one atomic “verify and act” transaction.
- Do not persist unlock codes in Keychain or app preferences.
- Clear secure text state on backgrounding and after attempts.

## Authentication

### Authentication decision

Use one Supabase Auth tenant and one canonical application account across web,
iOS, and any future Android client:

- Email OTP is the universal sign-in and recovery method.
- Sign in with Apple is required for iOS v1 and is also offered on the web.
- Sign in with Google is offered on the web and iOS, with configuration reusable
  by a future Android app.
- WhatsApp and SMS authentication are deferred from v1. They may be reconsidered
  only with a funded production provider, an abuse/cost-control design, and a
  secure Supabase-session binding.

Provider identities are authentication methods attached to one account, not
separate player profiles. The server-owned identity-completion flow must resolve
the authenticated Supabase user to `players.user_id`; clients must never merge
accounts merely because two unverified identifiers match.

### Email OTP

- Use Supabase Auth through the native SDK.
- Universal links are optional for code entry but configure associated domains
  if invite links or magic links are introduced.
- Use `.oneTimeCode` content type and generic responses.
- Configure production OTP expiry, resend cooldown, abuse controls, and SMTP.

### Sign in with Apple

- Use native Authentication Services in the iOS app with a cryptographically
  random nonce validated by Supabase.
- Use Apple OAuth for the web through a Services ID associated with the primary
  App ID, registered HTTPS domains, and exact return URLs.
- Store the Apple `.p8` signing key only in approved server-side secret storage.
- Generate and rotate the Apple OAuth client secret before its six-month expiry;
  monitor expiry and alert well before authentication can fail.
- Capture Apple-provided name data only on the first native authorisation and
  complete missing profile fields in Roo Bin onboarding.
- Handle revoked credentials and revoke Apple tokens during account deletion.

### Sign in with Google

- Use Supabase Google authentication on the web and the supported native
  provider flow on iOS.
- Configure separate OAuth client IDs for web, iOS, and future Android clients
  under the same approved Google Cloud project.
- Use exact redirect URIs, verified app identifiers, PKCE where applicable, and
  a nonce for native ID-token exchange.
- A future Android client should use Android Credential Manager and the same
  Supabase backend rather than introduce Firebase Auth or a second user store.

### Identity linking and recovery

- Automatically link only where Supabase can establish the provider identities
  belong to the same verified user under the approved linking policy.
- Require recent authentication before manual provider linking or unlinking.
- Never allow unlinking the final usable sign-in/recovery method.
- Detect legacy duplicate players or conflicting provider identities and route
  them to a logged, least-privilege recovery process; never guess or overwrite.
- Test hidden-email Apple accounts, changed Google email, provider revocation,
  concurrent first sign-in, and an existing email-OTP user adding a provider.

## Local data and caching

- Store session secrets only using an approved secure mechanism.
- `UserDefaults` may store selected team, display preferences, and cache metadata
  but not OTPs, unlock codes, invite tokens, or raw access/refresh tokens.
- Use a bounded, versioned cache for read models.
- Mark cached content with team and user identity and purge it on sign-out,
  account deletion, membership removal, or identity change.
- Apply iOS data-protection classes to files if a disk cache is introduced.
- Exclude regenerable cache from iCloud backup.

## Networking

- HTTPS only; do not add arbitrary App Transport Security exceptions.
- Use the Supabase SDK or `URLSession`.
- Define timeouts, cancellation, retry classification, and response-size limits.
- Retry idempotent reads with bounded backoff; retry mutations only with
  idempotency.
- Redact authorization headers, tokens, OTPs, contacts, unlock data, and raw
  database errors from logs.
- Certificate pinning is not a default requirement and can harm availability;
  add it only with a managed rotation design and explicit threat justification.

## Image handling

- Use `PhotosPicker`; request broad photo-library permission only if genuinely
  needed.
- Decode locally, correct orientation, crop/fit with user-visible preview, strip
  metadata, and encode to the agreed canonical JPEG/PNG/WebP format.
- Enforce decoded pixel and byte limits to prevent resource exhaustion.
- Server validates membership, signature/MIME, dimensions, and file size.
- Define storage replacement and deletion lifecycle.
- Provide an accessible fallback when a logo fails to load.

## RackEm boundary

- Native client never scrapes HTML.
- Backend owns upstream requests, parsing, caching, throttling, and source
  provenance.
- Return a stable typed DTO.
- Preserve manual workflows and show cached/stale status during outages.
- Add contract fixtures so upstream markup changes fail tests before production.

## Privacy and App Store engineering

- Include a valid `PrivacyInfo.xcprivacy` generated from actual app/SDK behaviour.
- Declare every required-reason API used by app or dependencies with approved
  reasons.
- Complete App Store privacy answers from a data-flow inventory.
- Provide privacy-policy and support links in app and metadata.
- Implement in-app account deletion.
- Avoid tracking and the ATT permission entirely unless a later business
  decision makes tracking essential.
- Use purpose strings only for permissions actually requested and explain the
  immediate user benefit.

## Observability

- Start with privacy-preserving server operational logs and Apple’s native crash
  diagnostics.
- If third-party diagnostics are added, record data fields, retention, sampling,
  processor, privacy-manifest impact, App Store disclosure, and opt-out/consent
  requirements.
- Use correlation IDs that are not secrets or stable cross-service tracking IDs.
- Security events belong on the server.

## Testing strategy

### Backend

- Migration-from-production-copy tests.
- RLS matrix tests for every role/status and cross-team access.
- RPC contract, validation, idempotency, rate-limit, and transaction tests.
- Account deletion and retention tests.
- RackEm parser fixtures and failure tests.

### iOS unit tests

- Domain calculations, money, dates, mapping, permissions-as-presentation,
  reducers/view models, validation, and error mapping.

### Integration tests

- Supabase local/test project contract tests.
- Auth restore/expiry, team switching, aggregate saves, and conflicts.

### UI tests

- Primary journeys J01–J12 on at least small and current large iPhones.
- VoiceOver smoke tests and accessibility identifier coverage.
- Dynamic Type, Reduce Motion, dark appearance, offline/error, interrupted OTP,
  background/foreground, and low-memory cases.

### Compatibility

- Web regression tests run against every shared migration.
- A release build must work against production-like RLS without service keys.

## Environments and delivery

Use separate development, staging, and production Supabase projects. Never put a
service-role key in the app. Xcode configurations should supply only public
client configuration appropriate to each environment. Secrets for server
functions live in server-side secret storage.

CI gates:

- Swift format/lint policy once selected.
- build and unit tests;
- backend migration/policy tests;
- dependency and secret scanning;
- privacy manifest validation;
- archive with current required Xcode/iOS SDK;
- staged TestFlight deployment.

## Open decisions

These must be confirmed before project scaffolding:

- final App Store product name;
- bundle identifier and Apple developer legal entity/team;
- oldest supported iOS version and iPad availability;
- production Apple/Google provider identifiers, domains, and redirect URLs;
- ownership and automation of the six-month Apple OAuth secret rotation;
- whether RackEm is required for v1;
- public versus private team logos;
- account deletion, team closure, and historic-record anonymisation rules;
- platform administrator support policy;
- notification channels for v1;
- privacy-policy controller/legal contact and support URL.
