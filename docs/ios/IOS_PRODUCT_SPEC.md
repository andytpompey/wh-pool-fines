# iOS Product Specification

Status: proposed baseline for product approval  
Product name: Roo Bin  
Primary platform: iPhone

Approved product metadata:

- Installed and App Store name: `RooBin`
- App Store subtitle: `The digital sin bin for teams`
- Marketing proposition: `RooBin – The digital Sin Bin for teams and clubs`
- Bundle identifier: `com.roobin.app`
- Apple Developer account: Individual — `Andy Thomas`
- Apple Developer enrollment ID: `8SC6V3W2FN` (not a signing Team ID)
- Apple Developer Team ID: deferred until paid membership activation
- Minimum deployment target: iOS 17
- v1 device family: iPhone only
- Orientation: portrait-first; supported layouts remain usable in landscape
- Native iPad experience: deferred

## Product intent

Roo Bin lets amateur pool teams manage fixtures, participating players, fines,
subs, balances, and payment status in a shared team workspace. The iOS app must
preserve every supported web journey while adopting native iOS interaction,
accessibility, privacy, and security patterns.

“Parity” means equivalent user outcomes and data, not pixel-identical screens.

## Users and roles

### Member

- View teams, dashboard, fixtures, fines, subs, and balances.
- Manage their own profile and preferences.
- Join or create a team where permitted by the onboarding model.

### Vice-captain

- All member capabilities.
- Create/edit matches and manage operational team data.
- Manage fine types, seasons, payments, settings, invites, and roster details as
  allowed by the agreed permission matrix.
- Perform protected actions with team unlock verification.

### Captain

- All vice-captain capabilities.
- Manage roles and captaincy.
- Configure and recover the team unlock code.

### Platform administrator

- Support and oversight capabilities defined by an explicit server policy.
- Cannot retrieve or use team unlock codes.
- Must not silently impersonate team members.

## Information architecture

Use a native four-tab structure:

1. **Home** — dashboard, season scope, balances, leaderboard, recent activity.
2. **Matches** — fixture list, match details, create/edit/submit workflows.
3. **Fines** — fine and sub ledger, filters, paid/unpaid actions.
4. **Settings** — profile, team switcher, team management, privacy, support,
   account deletion, and sign out.

Use `NavigationStack` within each tab. Present short creation/editing tasks as
sheets; use full-screen flows only for onboarding, authentication, or genuinely
complex multi-step work. Destructive actions require native confirmation and,
where applicable, server-verified unlock authorisation.

## Primary journeys

### J01 — Register or sign in

1. User chooses Sign in with Apple, Sign in with Google, or email OTP.
2. For email OTP, the app explains the data used and sends a code without
   revealing whether a player record already exists.
3. The selected provider completes through the native system flow where
   available; email codes use system autofill.
4. The backend transaction attaches the verified provider identity to one
   canonical account and links or creates one player profile.
5. A conflict is stopped and routed to recovery instead of creating an unsafe
   merge or duplicate.
6. The user lands in their last valid team or onboarding.

Success: one authenticated identity, no duplicate player, recoverable error
state, token held in secure storage.

### J02 — Create or join a team

- Create: supply team name; backend creates team and captain membership
  atomically.
- Join: enter or paste a join code; backend applies the agreed join policy and
  creates an active membership.
- If an invite/deep link is supplied, resolve it after authentication.

Success: team becomes current and appears in team switching.

### J03 — View and switch team

The current team scopes every dashboard, match, fine, season, and management
query. Switching is explicit and the UI always displays the current team.
Removed or missing memberships fall back safely to another active team or
onboarding.

### J04 — View dashboard

The user sees team-level totals and individual balances, leaderboard positions,
payment state, and relevant recent/next match information. Selecting a season
updates all dashboard metrics and persists per user/per team. If the season is
deleted, selection falls back to All seasons.

### J05 — Create a match

A captain or vice-captain selects date, season/competition, home or away context,
opponent, participating players, and drivers. The app calculates subs using the
team’s current settings. Validation prevents incomplete or contradictory data.

### J06 — Record and submit fines

An authorised user adds fines by player and fine type, sees calculated totals,
reviews subs, then submits the match. Submission locks ordinary editing.
Historical labels and monetary values remain stable even after later profile or
fine-type changes.

### J07 — Correct a submitted match

A captain/vice-captain explains the impact, supplies the team unlock code, and
the server authorises and performs the protected action. The result and actor
are audited. Failure never exposes which part of the secret was incorrect.

### J08 — View ledger and record payment status

Authorised users filter fines/subs by player, season, and payment state and mark
eligible entries paid or unpaid. The app displays the total effect and supports
retry without double-applying a mutation.

### J09 — Manage team

Authorised roles manage:

- team name, logo, subs enablement, sub amount, and driver rules;
- members, roles, captain transfer, and removal;
- pending invitations;
- fine types and seasons;
- RackEm connection and imported seasons;
- team unlock-code lifecycle.

Unavailable actions remain visible only where explaining role restrictions is
useful; otherwise they are omitted. Server rejection remains authoritative.

### J10 — Manage profile and notifications

The user edits display name, email/mobile under verified-change rules, manages
linked Apple/Google sign-in methods, and sets team-notification preferences.
Sensitive identity changes, linking, and unlinking require recent authentication
and re-verification. The final usable sign-in/recovery method cannot be removed.

### J11 — Delete account

The user opens Settings → Privacy & Account → Delete Account, reviews:

- teams and role obligations;
- what is deleted, anonymised, transferred, or retained;
- loss of access and any pending actions.

After reauthentication and final confirmation, a server workflow completes or
queues deletion, signs the device out, and reports status. A sole captain must
transfer captaincy or follow the agreed team-closure path.

### J12 — RackEm import

An authorised team leader selects the league/team and imports or refreshes
fixtures. The app shows source, last refresh, new/updated counts, and stale/error
states. Manual match workflows remain available when RackEm is unavailable.

## Screen inventory

| Area | Screens or sheets |
|---|---|
| Authentication | Welcome, Apple sign-in, Google sign-in, OTP request, OTP verification, account conflict/recovery, profile completion |
| Team onboarding | No-team state, create team, join team, invite acceptance |
| Home | Dashboard, season picker, balance/leaderboard detail |
| Matches | Match list, match detail, create/edit match, player/driver picker, fine editor, submit confirmation, unlock confirmation |
| Fines | Ledger, filters, player detail, payment confirmation |
| Settings | Profile, team switcher, create/join team, privacy and account, support, sign out |
| Team management | Overview, settings/logo, players, member detail, invites, fine types, seasons, RackEm connection, security |
| System states | Loading, empty, offline, stale cache, retryable error, forbidden, removed membership, maintenance |

## Feature parity matrix

| Capability | Web baseline | iOS release requirement |
|---|---:|---:|
| Email OTP | Yes | Required |
| Sign in with Apple | No | Required on iOS and web |
| Sign in with Google | No | Required on iOS and web; reusable for future Android |
| Provider identity linking/recovery | No | Required |
| WhatsApp/SMS OTP | Configurable | Deferred from v1 |
| Profile/preferences | Yes | Required |
| Create/join/switch team | Yes | Required |
| Dashboard/season preference | Yes | Required |
| Match create/edit/submit | Yes | Required |
| Fine and sub management | Yes | Required |
| Paid/unpaid tracking | Yes | Required |
| Roles and roster | Yes | Required |
| Invites | Yes; delivery may be placeholder | Required with real delivery or clearly reduced scope |
| Fine types/seasons | Yes | Required |
| Team settings/logo | Yes | Required |
| Unlock-code workflows | Yes | Required after server redesign |
| Audit events | Partial | Required for privileged mutations |
| RackEm import | Yes | Required unless explicitly deferred with product approval |
| JSON bulk import | Data module only/legacy | Admin migration tool, not an end-user iOS requirement |
| Account deletion | No | Required |
| Privacy/support pages | No | Required |

## Behavioural requirements

### Loading and refresh

- Show existing cached content immediately when safe, with last-updated state.
- Refresh on foreground and user pull-to-refresh.
- Never replace valid content with a blank screen because one secondary request
  failed.
- Display whether RackEm content is fresh, stale, or unavailable.

### Offline

Initial public release is read-through cache, not offline-first editing.
Previously loaded, non-sensitive team summaries may be viewed offline. Mutations
require connectivity and remain clearly pending only if an idempotent queue has
been deliberately implemented and tested.

### Errors

- Use actionable, human language.
- Preserve entered form data after retryable failures.
- Distinguish validation, permission, connectivity, conflict, and service errors.
- Do not expose raw database, policy, token, or scraper details.

### Money

- Store and calculate authoritative values using Postgres numeric/minor-unit
  rules, never binary floating-point assumptions.
- Display locale-aware GBP currency.
- Preserve the amount applied when a fine/sub was recorded.

### Dates and time

- A match date is a calendar date, not an instant; avoid timezone date shifts.
- Audit and refresh timestamps are UTC instants displayed in the user locale.

### Destructive actions

- State what will be affected.
- Use role and unlock requirements defined by the server.
- Do not use swipe-to-delete for high-impact records without confirmation.
- Return a stable success state even if the client loses connection after the
  server committed the operation.

## Native design requirements

- Follow Apple platform conventions while retaining the Roo Bin dark/amber
  brand.
- Use semantic colours and system materials; support light/dark appearance only
  after both are intentionally designed. A dark-only v1 is acceptable if
  contrast and system presentation remain correct.
- Minimum 44 × 44 point interactive targets.
- Support Dynamic Type without clipping or hiding actions.
- Provide VoiceOver labels, values, hints, headings, and logical traversal.
- Do not use emoji as the sole accessible label for navigation or status.
- Do not communicate paid/unpaid, success/failure, or role solely through colour.
- Respect Reduce Motion, Increase Contrast, and Bold Text.
- Use native secure fields and one-time-code text content types.
- Support paste and Password AutoFill conventions where applicable.

## Privacy requirements

Collect only data required for app functionality. At the current product scope,
the likely App Store disclosures include identifiers/contact information,
user-generated team/profile content, photos selected for team branding, product
interaction records, and diagnostics if added. Exact declarations must be
generated from the final binary, SDKs, backend processors, and production data
flow—not copied from this provisional list.

The privacy policy must be linked inside the app and in App Store Connect and
must describe collection, use, sharing/processors, retention, deletion, and user
choices.

## Non-goals for the first App Store release

- Replacing Supabase with CloudKit or a second database.
- A web-wrapper application.
- A native Android application in the iOS v1 delivery scope; authentication and
  backend decisions must nevertheless remain Android-compatible.
- iPad-specific multi-column optimisation (the app should still run safely if
  iPad compatibility is enabled).
- Apple Watch, widgets, Live Activities, or push notification campaigns.
- Offline mutation queues.
- New monetisation or in-app purchases.
- Unreviewed analytics, advertising, or tracking SDKs.

## Product acceptance

The iOS release is acceptable when every required parity row has automated or
documented acceptance evidence, all P0/P1 security findings are closed, account
deletion works end-to-end, accessibility and device testing pass, the privacy
artefacts match actual behaviour, and an external TestFlight cohort completes
the primary journeys without data corruption or web-client regression.
