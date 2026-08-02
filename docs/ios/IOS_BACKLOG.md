# iOS Delivery Backlog

Status: proposed implementation sequence  
Story IDs are stable references; they do not imply repository issue numbers.

## Working rules

- Complete increments in order unless a dependency is explicitly removed.
- P0 security work blocks production native writes.
- Every story includes unit/integration evidence appropriate to its risk.
- A story is not done until web compatibility is checked where it changes the
  shared backend.
- Apple requirements must be rechecked before external TestFlight and submission.

## Increment 0 — Verified foundation

### Epic E0 — Baseline and decisions

#### IOS-001 — Capture the live deployment

As the delivery team, we need an export of the live Supabase schema, migrations,
functions, grants, RLS/storage policies, Auth configuration, and bucket settings
so the native app is built against reality.

Progress: completed 30 July 2026. Evidence and confirmed drift are recorded in
`LIVE_SUPABASE_AUDIT_2026-07-30.md`. The live project has no Supabase migration
history relation, so migration provenance can only be reconstructed from the
repository and saved SQL snippets.

Acceptance:

- Sanitised exports are stored or referenced securely.
- Repository migrations are compared to live state.
- Drift and required remediation are recorded.
- No production rows or secrets are committed.

#### IOS-002 — Make database setup reproducible

Progress: completed 30 July 2026. A reconstructed core baseline and terminal
team-bootstrap security migration now apply cleanly from zero. Local reset and
schema lint pass, all 16 migration versions are recorded on `Roo Bin Staging`
(`mwpmibgtqkhivarvcttw`), and the three team-administration `allow all` policies
are absent. `schema.sql` is explicitly historical and README setup uses the CLI
migration workflow. Production was not changed.

Acceptance:

- New staging database can be created from version-controlled migrations.
- No permissive `allow all` policy remains.
- `schema.sql` is removed, regenerated safely, or clearly made non-executable.
- README setup steps match the verified process.

#### IOS-003 — Approve product identity and platform range

Progress: product naming approved 31 July 2026. The installed and App Store name
is `RooBin`; the App Store subtitle is `The digital sin bin for teams`; the full
marketing proposition is `RooBin – The digital Sin Bin for teams and clubs`.
The permanent bundle identifier is `com.roobin.app`. Developer team/legal
entity is intended to be the individual account `Andy Thomas`. The supplied
`8SC6V3W2FN` value is an enrollment ID and must not be used as a Team ID.
Apple Developer Program activation and the real Team ID are intentionally
deferred; the initial project may use unsigned Simulator builds or a local
Personal Team. The minimum deployment target is iOS 17. The v1 target is iPhone
only, with portrait-first layouts that remain usable in landscape. A native iPad
experience is deferred rather than shipping an enlarged compatibility layout.

Status: product and build decisions complete for Simulator scaffolding.
Distribution signing, Sign in with Apple, TestFlight, and App Store submission
remain gated on paid membership activation and confirmation of the real Team ID.

Acceptance:

- Product display name, bundle identifier, developer team/legal entity, minimum
  iOS version, supported devices, and iPad availability are recorded.
- Xcode 26+ and iOS 26 SDK+ upload requirement is reflected in CI.

#### IOS-004 — Approve parity and v1 scope

Decision update: email OTP remains the universal fallback; Sign in with Apple
and Sign in with Google are in v1 for iOS and web; WhatsApp/SMS authentication
is deferred until a funded production provider and abuse-control model are
approved. Android is not in the iOS v1 build, but the shared auth design must
support it without a second identity store.

Acceptance:

- Every row in the product parity matrix is Required, Deferred, or Removed with
  an owner and reason.
- Authentication-provider and RackEm v1 decisions are explicit.
- Existing web journeys remain supported.

#### IOS-005 — Define privacy and retention

Progress: implementation draft completed 31 July 2026 in
`PRIVACY_RETENTION_DRAFT.md`. It inventories current and planned processors,
data classes, device cache, proposed deletion handling, and proposed retention
windows. Named owners, public URLs, sole-captain closure, historic-name
anonymisation, RackEm rights, and final retention periods require product/legal
approval and remain in `DEFERRED_ACTIONS.md`.

Acceptance:

- Data inventory covers Supabase, email/WhatsApp processors, RackEm, storage,
  logs, and planned diagnostics.
- Retention/deletion rules are approved for auth user, player, memberships,
  invites, logos, audit logs, matches, fines, and subs.
- Privacy-policy and support owners/URLs are assigned.

### Epic E1 — Backend security boundary

#### IOS-006 — Enforce the role matrix server-side

Progress: completed on staging 30 July 2026. Role-aware policies are deployed
and the 17-case automated matrix covers active member, invited, removed,
vice-captain, captain, platform administrator, and cross-team access/mutation.

Acceptance:

- Default-deny RLS is applied.
- Reads/writes are tested for anonymous, invited, active member, removed member,
  vice-captain, captain, platform admin, and cross-team access.
- Members cannot perform leader-only writes using direct API calls.

#### IOS-007 — Secure identity linking

Progress: completed on staging 30 July 2026. Authenticated server-owned linking
is deployed; anonymous lookup/registration is removed; email OTP uses the new
function; conflicting takeover is tested; and the `auth_user_id` compatibility
removal gates are recorded in `STAGING_SECURITY_VERIFICATION_2026-07-30.md`.

Acceptance:

- Verified auth creates/links one player transactionally.
- Public endpoints do not enumerate player emails or mobile numbers.
- Concurrent or conflicting links cannot take over an existing identity.
- `players.user_id` is canonical and deprecated linkage has a migration plan.

#### IOS-008 — Move unlock verification to the server

Progress: completed on staging 30 July 2026. Server hashing, secret-column
redaction, durable rate limits, audit, and 60-second action grants are deployed.
Each supported protected mutation now consumes its matching grant atomically,
with replay, wrong-action, and cross-team tests passing.

Acceptance:

- Clients cannot select/read unlock hash or salt.
- Durable server rate limits apply.
- Verification and protected action are atomic or use a short-lived,
  single-purpose grant.
- Success/failure attempts are server-audited without secrets.

#### IOS-009 — Make privileged mutations transactional

Progress: completed on staging 30 July 2026. Protected mutations consume grants
atomically; whole-match aggregate saves, captain transfer, and payment batches
are transactional; retryable operations use actor-scoped idempotency keys and
stored responses. All rollback and retry tests pass.

Acceptance:

- Match aggregate save, captain transfer, member removal, destructive actions,
  and payment updates have atomic server operations.
- Retryable mutations support idempotency.
- Audit write failure cannot silently detach from the protected mutation.

#### IOS-010 — Secure notification and invite endpoints

Status: backend and client hardening complete on staging on 2026-07-30.
Transactional email delivery and WhatsApp OTP are fail-closed until their
provider credentials are configured in Supabase. See
`STAGING_COMMUNICATIONS_SECURITY_VERIFICATION_2026-07-30.md`.

Acceptance:

- Endpoints require authenticated access.
- Server resolves actor, role, team, and recipients.
- OTPs, invite tokens, unlock codes, and recipient lists are redacted from logs.
- Rate limit, replay, expiry, and failure behaviour are tested.

#### IOS-011 — Implement account deletion backend

Progress: completed on staging 1 August 2026. A recent-auth-only server contract
preflights captaincy and record impact, blocks captains until they transfer teams
with other active members, closes sole-member teams, deletes the Auth identity,
profile, memberships and addressed invitations, and removes retained ledger
player references. Historical snapshot names become a stable random alias drawn
from the team's sport vocabulary; existing teams default to pool and future
sports can add approved terms without changing deletion logic. Sole-team logo
cleanup runs through a server-owned Edge Function and the supported Storage API.

Acceptance:

- A reauthenticated user can initiate full deletion.
- Sole-captain and owned-team rules are enforced.
- Auth identity and personal data are deleted/anonymised per the approved policy.
- Logos/tokens/sessions/cache consequences are covered.
- Operation is idempotent and status can be reported.

#### IOS-012 — Establish backend contract and staging

Progress: v1 contract draft completed 31 July 2026 in `BACKEND_CONTRACT.md`.
It records environment separation, approved authenticated RPCs and Edge
Function messages, RLS read projections, stable error categories, idempotency,
versioning, secret boundaries, and prohibited native patterns. Initial Swift
DTOs, environment validation, request and error primitives exist. Remaining
work includes server replacements for identified legacy direct privileged
writes, generated schema types, contract fixtures, and final endpoint version
enforcement.

Acceptance:

- Versioned endpoint/RPC catalogue and typed DTOs are documented.
- Development, staging, and production are separated.
- No service-role secret can enter a client bundle.
- Web client passes smoke tests against the hardened staging backend.

## Increment 1 — Native walking skeleton

### Epic E2 — iOS foundation

#### IOS-020 — Scaffold the native project

Progress: implementation started 31 July 2026. Xcode 26.6 and XcodeGen 2.46 are
installed. The reproducible SwiftUI project, app target, unit-test target,
iPhone/iOS 17 settings, unsigned signing baseline, four-tab shell, assets, and
local build instructions exist under `ios/`. Project generation and Xcode
scheme/target discovery pass. Compilation and tests remain pending completion of
the separately downloaded iOS 26.5 Simulator runtime.

Acceptance:

- SwiftUI project uses the approved identifier and deployment target.
- App, test, and UI-test targets build in CI with the current required SDK.
- Environments and configuration contain no secrets.
- Repository ownership and build instructions are documented.

#### IOS-021 — Establish design system and app shell

Progress: implementation started 31 July 2026. The native four-tab shell uses
standard `TabView`, `NavigationStack`, and `ContentUnavailableView` controls.
Initial dark zinc/amber brand tokens, semantic status colours, spacing, radius,
44-point control sizing, card surface, and loadable-state model are defined.
Feature-specific screens and full accessibility acceptance remain open.

Acceptance:

- Four tabs and typed navigation work.
- Roo Bin colour, typography, spacing, icon, control, loading, empty, and error
  tokens are defined using native controls.
- Dynamic Type and 44-point target checks pass on the shell.

#### IOS-022 — Implement networking and error model

Progress: implementation started 31 July 2026. A dependency-free actor-isolated
`NetworkClient`, typed requests, idempotency header support, 30-second timeout,
cancellation preservation, and safe domain-error mapping exist. Supabase
authentication headers, correlation, bounded retry policy, response-size limit,
and integration tests remain open.

Acceptance:

- Repositories isolate Supabase/API calls from views.
- Cancellation, timeout, retry classification, correlation, and redaction rules
  are implemented.
- Domain errors map to user-safe messages.

#### IOS-023 — Implement secure session storage

Progress: implementation started 31 July 2026. Typed provider/session state,
main-actor app session lifecycle, expiry handling, team-selection clearing, and
an ephemeral test/preview store exist. Persistent storage is deliberately not
implemented until the Supabase Swift secure-session mechanism is reviewed; raw
tokens must not be stored in `UserDefaults`.

Acceptance:

- Supabase session restores and refreshes safely.
- Secret material is stored only in the approved secure mechanism.
- Sign-out clears session and user/team caches.
- Expired/revoked sessions return to authentication without data leakage.

#### IOS-024 — Add privacy manifest and dependency governance

Progress: implementation started 31 July 2026. A valid empty-state
`PrivacyInfo.xcprivacy` declares no tracking, tracking domains, collected-data
types, or required-reason API access in the current shell. The dependency
register records Apple frameworks and build tooling; no third-party runtime SDK
is currently linked. The manifest and register must evolve with actual features.

Acceptance:

- `PrivacyInfo.xcprivacy` exists and is valid.
- Required-reason APIs and each dependency are inventoried.
- Dependency additions require privacy/security review.

## Increment 2 — Identity and teams

### Epic E3 — Authentication and onboarding

#### IOS-030 — Email OTP request and verification

Progress: live staging integration completed 31 July 2026. Native email OTP now
requests and verifies Supabase eight-digit codes, restores a device-only Keychain
session, distinguishes request and verification failures, and routes through the
authenticated app coordinator. Refresh-token rotation, resend cooldown, account
enumeration tests, and Simulator UI tests remain open.

Acceptance:

- Email validation, resend cooldown, one-time-code autofill, loading, expiry, and
  retry states work.
- Responses do not enumerate accounts.
- Interrupted/backgrounded flow recovers safely.

#### IOS-031 — Complete authenticated profile

Progress: live staging integration completed 31 July 2026. The authenticated
bootstrap detects whether the current identity has a player profile, captures a
required display name when needed, and calls the security-definer
`ensure_current_player` RPC. Conflict recovery and integration tests remain open.

Acceptance:

- New user supplies only required profile data.
- Existing verified player is linked without duplication.
- Conflicts have a safe support/recovery route.

#### IOS-032 — Implement Sign in with Apple on iOS

Acceptance:

- Native Authentication Services flow uses a random nonce and produces a valid
  Supabase session.
- First-authorisation name handling and hidden Apple relay email are supported.
- Credential revocation and sign-out states fail safely.
- Apple token revocation is integrated with IOS-011/IOS-073 account deletion.

#### IOS-033 — Create team

Progress: live staging integration completed 31 July 2026. The native journey
calls authenticated `create_team_with_captain`, receives the created team,
selects it immediately, and exposes the same create action from Settings.
Retry/idempotency and end-to-end integration tests remain open.

Acceptance:

- Team and captain membership are created atomically.
- Validation and duplicate/retry behaviour are defined.
- New team becomes current.

#### IOS-034 — Join team

Progress: live staging integration completed 31 July 2026. The native join-code
journey calls authenticated `join_team_by_code`, selects the returned membership,
and reports non-enumerating safe errors. Invalid/expired and cross-team integration
tests remain open.

Acceptance:

- Code entry/paste and invalid/expired states work.
- Joining follows the approved membership policy atomically.
- Cross-team data is not exposed before successful membership.

#### IOS-035 — Switch and restore team

Progress: active membership loading and in-session switching completed 31 July
2026. The accessible picker displays roles and the current team, while an empty
membership list routes to create/join onboarding. Persisted team preference,
removal fallback, and integration tests remain open.

Acceptance:

- All active memberships appear.
- Selection scopes every feature and persists as a non-secret preference.
- Removed/unavailable selection falls back safely.

#### IOS-036 — Accept invite/deep link

Progress: secure HTTPS fallback acceptance completed on staging 31 July 2026.
The previously missing `/invite` route now preserves the token through web
authentication and calls `accept_team_invite_by_token`; the server locks the
pending invite, verifies authenticated email and expiry, and activates
membership atomically. The fix is deployed at `roobin-staging.vercel.app`.
Opening the installed iOS app via Universal Link and resuming acceptance there
remain open pending Associated Domains configuration.

Acceptance:

- Universal link routes through authentication then resumes acceptance.
- Token is single-use and expires.
- Logs and analytics do not contain the token.

#### IOS-037 — Implement Apple authentication on the web

Acceptance:

- Apple Services ID is associated with the primary App ID.
- Production and staging HTTPS domains and exact callback URLs are registered
  separately.
- Apple OAuth completes into the same Supabase tenant and canonical account used
  by iOS and email OTP.
- The `.p8` key and generated client secret exist only in approved server-side
  secret storage.
- A monitored rotation process replaces the client secret before its six-month
  expiry and is rehearsed without user-visible downtime.

#### IOS-038 — Implement Google authentication on web and iOS

Acceptance:

- Approved Google Cloud project and consent/brand configuration are documented.
- Separate web and iOS OAuth client identifiers use exact origins, redirects,
  and bundle identifier.
- Web and native iOS flows produce valid sessions in the existing Supabase
  tenant without introducing Firebase Auth.
- Configuration records the future Android package/signing requirements and can
  add Android Credential Manager without changing the account model.
- Email OTP remains available when Google is unavailable or revoked.

#### IOS-039 — Implement provider linking, unlinking, and recovery

Acceptance:

- An existing email-OTP user can add Apple or Google without creating a second
  player or losing memberships and history.
- Linking and unlinking require recent authentication and server-authoritative
  verified identity evidence.
- The final usable sign-in/recovery method cannot be removed.
- Conflicting identities stop safely and provide a non-enumerating recovery or
  support path; no automatic destructive merge occurs.
- Tests cover Apple relay email, matching and changed emails, concurrent first
  sign-in, revoked providers, duplicate legacy players, and cross-team access.
- Web and iOS observe the same account and provider state.

## Increment 3 — Read parity

### Epic E4 — Home and read models

#### IOS-040 — Dashboard

Progress: live staging repository wiring completed 31 July 2026. The native
Home view loads the selected team's RLS-scoped members, seasons, matches, fines
and subs, then applies the verified web calculations for GBP totals, collection
rate, counts and player balances. Team changes and pull-to-refresh reload live
data, safe errors are visible, and all six Simulator unit tests pass. Live
parity testing with populated staging fixtures remains open.

Acceptance:

- Current team, totals, balances, leaderboard, and meaningful empty/error states
  match verified web calculations.
- Currency and date presentation are locale-correct.

#### IOS-041 — Season preference

Progress: native integration completed 31 July 2026. The season menu loads live
team seasons, scopes all dashboard calculations, persists the non-secret choice
per team on-device, reloads through the repository, and falls back to All
seasons when a saved season disappears. Multi-user device isolation and live
restart verification remain open.

Acceptance:

- All seasons and each available season can scope all metrics.
- Preference persists per user/per team.
- Deleted/unavailable selection falls back to All seasons.

#### IOS-042 — Match list and detail

Progress: source implementation started 31 July 2026. Native match list and
detail views use typed summaries, navigation values, submitted/draft text
status, date/venue/season/player/fine/total fields, pull-to-refresh boundary,
accessible combined rows, and production empty state. RLS repository queries,
sorting parity, stale-cache state, and integration/UI tests remain open.

Acceptance:

- Fixture source/status, venue, opponent, season, players, drivers, fines, subs,
  totals, and submitted state are represented.
- Pull-to-refresh and cached/stale states work.

#### IOS-043 — Fine/sub ledger

Progress: live RLS repository integration completed 31 July 2026. The native
ledger loads current-team fines and automatically generated subs with trusted
historic labels, GBP amounts, match dates, paid/unpaid text, and deterministic
newest-first ordering. Payment, kind, player and season filters plus
pull-to-refresh are wired and all six Simulator tests pass. Payment mutation
actions and populated parity/UI tests remain open.

Acceptance:

- Player, season, and payment-state filters match web behaviour.
- Paid/unpaid and fine/sub distinctions are accessible without colour.

## Increment 4 — Operational write parity

### Epic E5 — Matches and fines

#### IOS-050 — Create match

Progress: live staging integration completed 31 July 2026. Captains and
vice-captains can open the typed native form from Matches, choose an active
player, season, venue and away drivers, and save through the transactional,
idempotent `save_match_aggregate` RPC. Creation applies the team's live subs
amount, enabled state and driver exemption, then refreshes both Matches and the
Dashboard. The project compiles and all six Simulator unit tests pass. Live
creation, retry interruption and populated multi-player parity checks remain
open.

Acceptance:

- Date, season, competition, venue, opponent, players, and drivers are validated.
- Team subs settings produce the expected initial subs.
- Save is atomic and idempotent.

#### IOS-051 — Edit draft match

Live finding 31 July 2026: an away match can capture drivers during creation,
and configured driver exemption correctly prevents their subs charge, but the
native match detail cannot yet change drivers after creation. This is required
in this story.

Progress: participant/driver editing completed on staging 31 July 2026. Draft
match detail now changes active players and away drivers through an idempotent
server-owned operation. The server locks the draft, validates team membership,
prevents removal of players with recorded fines, and removes/restores subs from
current team settings without duplicates. Fixture-field editing and explicit
concurrent-version detection completed 31 July 2026. Captains and
vice-captains can edit date, opponent, venue and season without rebuilding the
match aggregate or altering fines/payment state. Venue changes deterministically
clear ineligible home drivers and reapply current team subs/driver exemptions.
Every fixture, participant, fine and sub mutation advances a server-owned match
version; stale fixture saves are rejected with a refresh message rather than
silently overwriting newer work. Failed saves retain the form values. Live
multi-device conflict and populated venue-change verification remain open.

Live testing clarification 31 July 2026: this control can only select existing
active team members; it does not add people to the team roster. IOS-062/IOS-064
must provide a usable roster/invite path before adding a second player can be
tested on a new team. If a selected player has a recorded fine, neither paying
the fine nor ordinary participant editing permits removal. The user must first
reassign it through IOS-052 editing or delete it through the IOS-054 protected
correction flow; the UI must explain and link to those actions.

Acceptance:

- Existing values load accurately.
- Captains and vice-captains can add/remove draft-match players and away drivers.
- Driver changes apply the current team rule deterministically: exempt drivers'
  subs are removed and restored when exemption no longer applies, without
  duplicating charges.
- Match detail, list, ledger and dashboard refresh after a successful change.
- Concurrent change conflict does not silently overwrite newer data.
- Failed save preserves local edits.

#### IOS-052 — Record fines and subs

Progress: initial live staging integration completed 31 July 2026. Match detail
shows trusted historic fine labels/amounts and automatically generated subs.
Captains and vice-captains can assign a configured fine type to a selected
draft-match player through the idempotent `add_match_fine` server operation;
the server derives player name, label and price and refreshes Matches and Home.
Fine editing/removal, player/driver changes and richer multi-player tests remain
open.

Acceptance:

- Fine types and player selection are accessible and efficient.
- Totals update deterministically.
- Historical labels and amounts are stored at the time of recording.

#### IOS-053 — Submit match

Progress: native implementation completed 31 July 2026. Draft match detail now
opens a full submission review of fixture, players/drivers, fines, subs and
totals, with explicit missing-information warnings and a second lock
confirmation. Submission uses a dedicated role-protected, transactional and
idempotent server RPC that locks the row, validates player assignments, marks
the match submitted and writes its audit event atomically. Successful submit
immediately locks ordinary native editing and refreshes Matches, Fines and the
Dashboard. Live populated Simulator and interrupted-request verification remain
open.

Acceptance:

- Review clearly shows resulting fines/subs and missing information.
- Successful submit locks ordinary editing.
- Duplicate taps/retries cannot duplicate records.

#### IOS-054 — Protected correction and deletion

Progress: native implementation completed 31 July 2026. Match detail and the
fine/sub ledger expose correction actions to captains and vice-captains. Fine
reassignment is restricted to active players in the same match, preserves the
amount/payment state, and uses an idempotent audited server RPC. Permanent fine
or sub deletion explains the effect, requires the server-verified team unlock
code and explicit destructive confirmation, then consumes its single-use grant
atomically with deletion and audit. Attempting to remove a draft-match player
with a fine now identifies the blocking record and opens its correction flow.
Captains can configure an initial 4–12 digit team unlock code natively when the
team requires one; change/recovery remains in IOS-067. Live populated Simulator
verification remains open.

Acceptance:

- Only eligible roles can initiate.
- Unlock code is server-verified and never persisted.
- Effect is explained and confirmation is explicit.
- Mutation and audit are atomic.
- A draft-match player blocked from removal by recorded fines is shown the
  affected entries and can navigate to reassign or protected-delete them.

### Epic E6 — Payments

#### IOS-055 — Mark entries paid/unpaid

Progress: native implementation completed 31 July 2026. Captains and
vice-captains can mark an individual fine or sub paid/unpaid from the ledger,
with an explicit confirmation showing player, entry type, amount and affected
record count. The mutation uses the transactional, idempotent
`update_payment_batch` RPC, records the operation and affected entries in the
audit log, prevents duplicate taps, and refreshes both the ledger and Dashboard.
Live staging and populated Simulator verification remain open.

Acceptance:

- Authorised roles can update eligible records.
- Amount and affected records are confirmed.
- Batch/individual retry cannot double-apply.
- Dashboard and ledger refresh consistently.

## Increment 5 — Management parity

### Epic E7 — Profile and team management

#### IOS-060 — Edit personal profile

Progress: native display-name and team-notification preference editing completed
31 July 2026 through a current-user-only server RPC. Historic fine/sub labels
remain unchanged. Verified email/mobile change and recent-auth journeys remain
deferred until those editable identity fields enter the approved v1 scope.

Acceptance:

- Display name and notification preference update.
- Email/mobile changes follow verified-change and recent-auth rules.
- Changes appear consistently across teams without changing historic labels.

#### IOS-061 — Manage team settings and logo

Progress: native team name, subs enablement/amount, driver exemption and logo
management completed 31 July 2026. PhotosPicker accepts Photos-supported HEIC/
HEIF inputs, offers crop/fit preview, renders a bounded metadata-free JPEG,
uploads only to the authorised team folder, and supports replacement/removal.
Live Simulator acceptance on 1 August 2026 confirmed upload, immediate cache-
busted refresh, persistence, and display on the native Home dashboard.

Acceptance:

- Subs, amount, driver rule, and branding match server validation.
- PhotosPicker accepts approved iPhone formats including HEIC/HEIF.
- Preview, crop/fit, metadata removal, upload, replacement, and fallback work.

#### IOS-062 — Manage roster and roles

Progress: native active-roster listing and server-owned role management built
31 July 2026. Captains can promote/demote vice-captains or atomically transfer
captaincy; captain and self invariants are enforced server-side and audited.

Acceptance:

- Permission matrix is correctly presented and server-enforced.
- Captain transfer is atomic and cannot leave a team without a captain.
- Self/sole-captain edge cases are handled.

#### IOS-063 — Remove member

Progress: native protected removal built 31 July 2026. The impact screen
explains immediate access loss and retained historic labels, requires the team
unlock code, and consumes the short-lived grant atomically with removal/audit.
Live Simulator acceptance on 1 August 2026 confirmed missing-code guidance,
in-sheet incorrect-code feedback, the five-minute brute-force lockout, and
successful removal with the valid recovered code.

Acceptance:

- Impact is explained.
- Server performs unlock-protected removal and audit atomically.
- Removed user loses access promptly and their client cache is invalidated.

#### IOS-064 — Manage invitations

Progress: initial native invite creation completed 31 July 2026. Captains and
vice-captains have an obvious Settings > Add player form with name/email
validation. It calls the authenticated `team-communications` Edge Function;
the server resolves authority and recipient, saves the invite and reports
whether email was delivered without returning the token to iOS. Pending invite
listing, delivery expiry, resend and revoke are now wired natively. Universal
Link handoff remains gated on Apple Associated Domains; the secure HTTPS invite
fallback remains active.
Live staging acceptance on 1 August 2026 confirmed the single secure email-link
journey without a second verification email.

Acceptance:

- Create, resend, revoke, expiry, and delivery state work.
- Placeholder “sent” behaviour cannot be mistaken for delivery.
- Tokens are not exposed after creation.
- A newly created team has an obvious Add player/invite journey before match
  participant selection; match editing lists the newly active member after
  acceptance and refresh.

#### IOS-065 — Manage fine types

Progress: native create/edit/protected-delete lifecycle completed 31 July 2026.
Edits are server-validated and audited; deletion requires the team unlock code,
and recorded fines retain their historic label and amount.

Acceptance:

- Create/edit/delete and validation match the shared contract.
- Historic fine labels/values remain unchanged.
- Deletion is protected and dependency impact is explained.

#### IOS-066 — Manage seasons

Progress: native manual-season create/edit/protected-delete lifecycle completed
31 July 2026. Imported seasons are read-only, source/type/match counts are
visible, and seasons with match history are blocked from deletion rather than
silently detaching historic matches.

Acceptance:

- Create/edit/delete, type, source state, and season dependencies are clear.
- Protected deletion cannot orphan or silently remove match history.

#### IOS-067 — Manage team unlock security

Progress: captain setup, atomic current-code rotation and server-delivered
recovery are wired natively as of 31 July 2026. Verification grants are
single-purpose/short-lived, codes never persist on device, and generated
recovery codes are sent only to eligible captains rather than returned to iOS.
Platform-support reset remains an approved operational/admin surface rather
than an end-user iOS feature.
Live staging/Simulator acceptance on 1 August 2026 confirmed fresh email
verification, server-side rotation, branded Resend delivery to the eligible
captain, invalidation of the old code, and successful protected use of the new
code.

Acceptance:

- Captain setup, change, recovery, and approved platform-support reset work.
- Secrets are never displayed to support users or stored on device.
- Notification failures produce a safe recovery path.

## Increment 6 — Integration, privacy, and release

### Epic E8 — RackEm

#### IOS-070 — Browse RackEm configuration

Conditional on IOS-004.

Acceptance:

- League/team catalogue uses the stable backend endpoint.
- Upstream error, timeout, cache, and stale states are visible.

#### IOS-071 — Import and refresh fixtures

Acceptance:

- User sees source and created/updated counts.
- Repeated refresh is idempotent.
- Manual matches are not overwritten.
- Parser contract tests use captured fixtures.

### Epic E9 — Privacy and support

#### IOS-072 — Privacy and support centre

Progress: the native privacy/support centre, production-domain privacy,
support/account-deletion and terms routes, matching native links, and
version/build display were implemented by 2 August 2026. The
`hello@trovefinds.co.uk` support mailbox was validated for receipt and reply on
2 August 2026. All production URLs were deployed and rendered-page verified on
2 August 2026 without changing the live production application version.

Acceptance:

- In-app privacy policy, user choices, support, version/build, and terms links
  are easy to find.
- URLs are live and match App Store metadata.

#### IOS-073 — Delete account in app

Progress: native and backend implementation completed 1 August 2026. The live
preflight explains record counts, sport-alias handling, teams that will close and
captaincy blockers. Deletion requires a fresh eight-digit email verification,
typing DELETE and a final destructive confirmation. The server requires a token
issued within ten minutes, deletes immediately, and the app clears its Keychain
session/cache and returns to signed-out state. Database, Edge bundle and Swift
contract tests pass; populated-account Simulator acceptance remains open.

Acceptance:

- Journey J11 works end-to-end.
- Reauthentication and final confirmation are accessible.
- Deletion status and retained/anonymised data are explained.
- Completion clears credentials/cache and signs out.

### Epic E10 — Quality and submission

#### IOS-080 — Complete automated test matrix

Progress: remote-safe baseline completed 31 July 2026. GitHub Actions workflows
now build/test web, apply and test the local Supabase migration stack, and run
the native Swift test target. Locally, 4 web permission tests, 87 pgTAP
authorization/transaction/security tests, the production Vite build and 13
Swift tests pass against the fully migrated schema. The Swift suite now covers
HTTP success decoding, defensive request headers, idempotency propagation,
status-to-domain-error mapping and malformed-response redaction without using a
live network. A three-test XCUITest smoke suite now covers signed-out launch,
all authentication choices, email-form navigation and provider fallback
messaging without sending OTPs or mutating staging. The combined 13 Swift unit
tests and 3 UI tests pass locally. Populated-account UI automation and the first
hosted CI run remain open; GitHub reported no workflow runs as of 2 August 2026
because the workflow and implementation changes remain local.
The populated Simulator core regression passed 1 August 2026: draft match and
participants, driver selection, fine creation, paid/unpaid updates, reassignment,
protected fine deletion and protected match deletion all refreshed correctly.

Acceptance:

- Backend RLS/RPC, Swift unit/integration, and primary UI journeys pass in CI.
- Web regression suite passes against final migrations.
- No known data-corruption or cross-team-access defect remains.

#### IOS-081 — Accessibility acceptance

Progress: implementation baseline includes semantic text role labels,
non-colour error/status cues, minimum 44-point menu targets and standard SwiftUI
controls that participate in Dynamic Type. Full VoiceOver and accessibility
settings acceptance is a documented desktop/device test gate.
Maximum accessibility Dynamic Type was exercised across all primary screens on
the iPhone 17 Pro Simulator on 1 August 2026. Home, Matches and Fines replace
constrained horizontal rows and metric grids with adaptive stacked layouts;
Settings, team settings, roster/removal, unlock security, match detail/add fine
and account deletion also passed visual and reachability checks. Remaining
acceptance covers VoiceOver, Bold Text, Increase Contrast and Reduce Motion.
Apple does not provide VoiceOver in iOS Simulator. Simulator label/value/order
and contrast auditing therefore uses Xcode Accessibility Inspector; true
gesture-and-audio VoiceOver acceptance remains a physical-device gate.
Accessibility Inspector screen-reader simulation was exercised successfully
against the running RooBin Simulator build on 1 August 2026.
Bold Text and Increase Contrast also passed across the primary UI. A transient
team-logo reload exposed an oversized no-cache asset; native processing now
emits cacheable 512-pixel JPEGs capped at 400 KB, and the saved-logo retest
passed after replacement.
Reduce Motion passed tab switching, match navigation, Settings forms and modal
presentation/dismissal on the iPhone 17 Pro Simulator on 1 August 2026.

Acceptance:

- VoiceOver, Dynamic Type, contrast, Reduce Motion, Bold Text, target sizes, and
  non-colour cues pass documented manual and automated checks.
- Primary journeys are completable using VoiceOver.

#### IOS-082 — Device and resilience acceptance

Progress: build and unit tests pass on the installed iPhone 17 Pro simulator.
Small-device, physical-device and adverse-network/session/storage scenarios are
recorded in `DEFERRED_ACTIONS.md` for interactive acceptance.
Default-text layout and core navigation also passed on the smallest available
iOS 26.5 runtime device, iPhone 17e, on 1 August 2026.
Backgrounding from match detail for 30 seconds and returning preserved the
session and left match/fine refresh operational without duplicate state.
Debug-isolated offline startup and retry showed a clear reachable error state,
did not crash or duplicate data, and preserved the saved session for the next
normal launch.
Debug-isolated expired-session startup returned to the signed-out flow without
exposing team data or crashing; the preserved real Keychain session remained
available after returning to normal launch mode.
Debug-isolated service outage startup showed a retryable temporary-unavailable
state without exposing cached team data or clearing the Keychain session. Retry
remained safe while the outage persisted, and normal service restoration
returned directly to Home without another sign-in.
Debug-isolated slow-network loading also passed: delayed Home refresh and
Matches loading completed without errors, duplicate data or frozen controls.
Logo uploads now use unique immutable object paths so the database switches to
a new logo only after the full settings save succeeds. A debug-isolated
interruption after storage upload retained the previous active logo and the app
recovered normally on relaunch.

Acceptance:

- Small and current large supported iPhones pass.
- Slow/offline network, background/foreground, token expiry, low storage,
  interrupted upload, service outage, and stale RackEm states pass.

#### IOS-083 — Complete privacy and App Store metadata

Progress: current Apple release requirements rechecked 31 July 2026. The local
toolchain uses Xcode 26.6 and iOS 26.5 SDK, satisfying Apple's requirement in
force since 28 April 2026 to upload iOS apps with Xcode 26+ and the iOS 26+ SDK.
The app privacy manifest declares its current UserDefaults required-reason API.
App Store Connect entry of the approved Nutrition Label answers, age rating and
screenshots remain release gates. Because RooBin creates user
accounts, Apple Guideline 5.1.1(v) makes working in-app account deletion a
submission requirement rather than an optional post-launch enhancement.
A complete v1 metadata draft, screenshot plan and production-domain URL set were
added on 2 August 2026. Live URL checks passed the same day. Final policy
decisions and the conservative App Privacy disclosure were owner-approved on
2 August 2026. The revised policy was published and verified the same day.
The conservative 9+ age-rating answer sheet was completed on 2 August 2026.
Screenshots and App Store Connect entry remain outstanding.

Acceptance:

- Privacy manifest matches final binary and SDKs.
- Privacy Nutrition Label matches actual data flows.
- Privacy/support URLs, age rating, category, screenshots, description, review
  contact, and export-compliance answers are complete.

#### IOS-084 — Internal TestFlight

Acceptance:

- Production-like backend and migration rehearsal pass.
- Internal testers complete J01–J12 as scoped.
- Crashes, blockers, data integrity, and privacy issues are triaged.

#### IOS-085 — External TestFlight

Acceptance:

- P0/P1 findings are closed.
- External beta information and privacy details are complete.
- Representative users complete the parity checklist.

#### IOS-086 — App Review submission

Acceptance:

- Final archive uses the currently required Xcode/iOS SDK.
- Review demo account or approved demo mode exposes all role-dependent features.
- Backend is live; sample team data and detailed review notes are supplied.
- Submission checklist is fully evidenced and signed off.

## Deferred backlog

### Epic E11 — Additional authentication channels

#### IOS-090 — Reassess SMS or WhatsApp authentication

Status: deferred beyond v1.

Acceptance:

- Product evidence shows email, Apple, and Google are insufficient.
- A production provider, budget, regional coverage, sender registration, and
  privacy/processor review are approved.
- Rate limits, CAPTCHA or equivalent abuse controls, spend caps, fraud
  monitoring, replay protection, and recovery behaviour are designed.
- Successful verification establishes or securely binds a Supabase session;
  `{ok: true}` alone is never treated as authentication.
- The new method passes identity-linking, deletion, and web/native regression
  tests before release.

### Epic E12 — Native product polish

#### IOS-091 — Complete native styling and branding

Status: in progress. The app icon and current native visual system were
approved on 2 August 2026. Four correctly sized raw screenshot framing captures
were retained on 2 August 2026; the Matches-list capture was discarded because
its staging data was not presentation quality. Final public recapture with
curated fictional demo data remains outstanding.

Bring the native app from its current RooBin colour and typography baseline to
an approved, consistent visual identity while preserving native iOS interaction
patterns and accessibility.

Acceptance:

- Approved RooBin app icon, launch treatment, wordmark, colour, typography and
  reusable component styling are applied consistently.
- Uploaded team branding appears promptly and consistently on appropriate Home,
  team-switching and team-management surfaces, with accessible fallbacks.
- Light/dark appearance, Dynamic Type, VoiceOver, contrast, reduced motion and
  the supported iPhone sizes pass visual acceptance.
- Native styling remains recognisably consistent with the web app without
  copying web-only interaction patterns.
- App Store screenshots use the approved final visual system and representative
  team branding.

### Epic E13 — Match lifecycle refinements

#### IOS-092 — Unlock submitted matches before editing

Status: deferred product improvement identified during Simulator acceptance on
1 August 2026.

Acceptance:

- Opening an edit, correction or deletion journey for a submitted match first
  requires a valid, purpose-bound team unlock grant.
- Fixture, participants, drivers, fines, subs and submission state cannot be
  changed through another client path without the same server enforcement.
- Successful unlock permits only the intended submitted-match operation for a
  short period and is consumed atomically.
- Incorrect attempts, lockout timing, cancellation and stale-version conflicts
  provide visible feedback without exposing the code.
- Every submitted-match mutation records an authoritative audit event.

#### IOS-093 — Allow fine deletion while a match is draft

Status: deferred product improvement identified during Simulator acceptance on
1 August 2026.

Acceptance:

- An authorised team leader can delete a fine from a draft match without
  entering the team unlock code.
- The UI still requires an explicit deletion confirmation and refreshes match,
  ledger and dashboard totals immediately.
- The server, rather than the client alone, verifies that the match is still a
  draft at mutation time and records the audit event.
- If the match was submitted or changed concurrently, deletion is rejected and
  the user is directed through the submitted-match unlock journey in IOS-092.
- Submitted-match fine deletion remains protected and cannot be bypassed by the
  web app or direct API access.

## Suggested first delivery slice

Begin IOS-001 through IOS-012 before feature implementation. IOS-020 through
IOS-024 can start once IOS-003 is decided, but should use mocked/staging
repositories until the hardened backend contract is ready.
