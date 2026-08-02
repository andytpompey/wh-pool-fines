# RooBin Shared Backend Contract

Status: v1 draft grounded in staging migrations and current web calls  
Reviewed: 31 July 2026

## Contract rules

- Supabase Auth issues identity; `auth.uid()` is the only client identity input.
- Postgres and RLS remain authoritative for durable state.
- Clients may read team-scoped projections allowed by RLS.
- Aggregate, privileged, protected, identity, invitation, and deletion writes
  use approved RPCs or Edge Functions.
- Client role, player, actor, audit, recipient, and platform-admin claims are
  never authoritative.
- UUID operation IDs are generated once per logical retryable mutation.
- Raw Postgres errors are mapped to stable application errors before display.
- The service-role key and provider secrets are server-only.

## Environments

| Environment | Purpose | Supabase project | Client configuration |
|---|---|---|---|
| Local | migration and contract tests | Supabase CLI | local URL plus publishable/anon key |
| Staging | integration and beta verification | `mwpmibgtqkhivarvcttw` | staging URL plus publishable key |
| Production | public web and App Store | existing live project | production URL plus publishable key |

No build may infer production from a missing variable. Each archive must declare
its environment visibly in build settings. Public project URLs and publishable
keys are configuration, not authorization; RLS remains mandatory.

## Approved authenticated operations

| Operation | Input | Output | Authority and retry |
|---|---|---|---|
| `ensure_current_player` | optional display name, mobile, preferred auth method | player row | authenticated identity; transactional linking |
| `create_team_with_captain` | team name, optional requested join code | team row | authenticated player; atomic team/captain creation |
| `join_team_by_code` | join code | team row | authenticated player; non-enumerating invalid response |
| `save_match_aggregate` | operation UUID, aggregate JSON | JSON result | captain/vice-captain; idempotent and transactional |
| `submit_match` | operation UUID, match UUID | JSON result | captain/vice-captain; validates, locks and audits atomically |
| `update_match_fixture` | operation UUID, match UUID, expected version, fixture fields | JSON result with new version | draft only; optimistic conflict check, subs recalculation and audit |
| `transfer_team_captain` | operation UUID, team and membership UUIDs | JSON result | current captain; idempotent and transactional |
| `set_team_member_role` | team ID, membership ID, role | JSON result | captain only; cannot demote captain |
| `remove_team_member` | operation/team/membership IDs, unlock grant | JSON result | team leader; protected, audited and transactional |
| `revoke_team_invite` | team ID, invitation ID | JSON result | active team leader |
| `update_current_player_profile` | display name, notifications flag | player row | current authenticated player only |
| `update_team_settings` | team settings and optional logo URL | team row | active team leader; server validated |
| `update_team_fine_type` | team/type IDs, name and amount | fine type row | active team leader; server validated |
| `save_team_season` | team/season IDs, name and type | season row | active team leader; manual seasons only |
| `change_team_unlock_code` | team ID, current-code grant and new code | JSON result | captain; consumes single-purpose grant |
| `account_deletion_preflight` | none | email, blockers, closing teams and historical counts | current authenticated player only |
| `delete_current_account` | none | deletion counts | token issued within ten minutes; atomic relational deletion |

`account-deletion` is the authenticated Edge Function boundary for IOS-011. It
removes sole-team logo objects through the Storage API, then invokes
`delete_current_account` with the user's fresh JWT. Historical fine/sub labels
use a random alias selected from `sport_anonymous_alias_terms`; one alias is
shared within a team and no alias identifier is shared across teams.
| `update_payment_batch` | operation UUID, team UUID, payment items | JSON result | captain/vice-captain; idempotent and transactional |
| `set_team_unlock_code` | team UUID, new code | redacted team result | captain; server hashing and audit |
| `verify_team_unlock_code` | team UUID, protected action, supplied code | short-lived single-purpose grant | rate limited; never persist response |
| `execute_protected_action` | grant UUID, entity type and UUID | JSON result | atomically consumes matching grant |
| `mark_team_unlock_reset_required` | team UUID | redacted result | authorised recovery flow |

## Edge Function contract

### `team-communications`

Requires a valid bearer session. Supported request bodies:

- invite: `{ "action": "invite", "teamId", "email", "displayName" }`
- resend: `{ "action": "resend", "inviteId" }`
- reset: `{ "action": "reset-unlock-code", "teamId", "reason" }`

The server resolves actor, team, role, player and recipients. Invite tokens and
unlock codes are never returned by client-callable database functions or logged.
Unlock reset requires a recently issued authentication token. Provider failure
is fail-closed where delivery is security-critical.

## Read projections

Native repositories may use RLS-scoped reads for teams, active memberships,
players shared with the current team, matches, match players, fines, subs, fine
types, seasons, pending invites visible to leaders, and team logo objects.
Every query must include current-team scope even when RLS would reject leakage.

## Prohibited native patterns

- Direct writes to `players.user_id`, `auth_user_id`, roles, membership status,
  captain ownership, unlock fields, audit logs, invite tokens, or aggregates.
- Multi-request match saves or captain transfers.
- Client-authored audit identity or recipient lists.
- Treating `{ "ok": true }` from an OTP provider as an authenticated session.
- Embedding service-role, Resend, Apple `.p8`, Google client secret, or Twilio
  credentials in an app or web bundle.

Current web helpers that directly relink players, change roles/status, accept
invites, or emit audit rows are compatibility debt. They require server-owned
replacement contracts before the native equivalent is implemented.

## Stable application error categories

`unauthenticated`, `forbidden`, `validation`, `notFound`, `conflict`,
`rateLimited`, `expired`, `offline`, `serviceUnavailable`, and `unexpected`.
Messages presented to users must not reveal account existence, policy details,
SQL, tokens, identifiers, recipients, or provider internals.

## Versioning

The initial contract version is `v1`. Additive response fields are allowed.
Removing or changing fields, permissions, semantics, or error categories
requires a new version or an app-enforced minimum backend version. Web regression
tests and native contract fixtures gate every shared migration.
