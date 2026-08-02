# Live Supabase Audit — 30 July 2026

Story: IOS-001  
Project: KangarooCourt, production branch  
Method: read-only Postgres catalogue queries and read-only Supabase Dashboard
inspection  
Data handling: no production application rows, user lists, secrets, API keys, or
connection strings were read or exported

## Outcome

IOS-001 is complete. The live structure is sufficiently captured to begin
IOS-002, but production security remediation must be prepared and tested in a
separate staging project before any policy is changed.

The live project contains substantial drift from the intended repository policy
state. RLS is enabled on all 12 public tables, but overlapping permissive
policies currently defeat team isolation on important tables.

## Live inventory

### Public tables

| Table | Columns | RLS |
|---|---:|---|
| app_users | 9 | Enabled |
| audit_logs | 10 | Enabled |
| fine_types | 5 | Enabled |
| fines | 9 | Enabled |
| match_players | 3 | Enabled |
| matches | 25 | Enabled |
| players | 11 | Enabled |
| seasons | 11 | Enabled |
| subs | 7 | Enabled |
| team_invites | 9 | Enabled |
| team_memberships | 6 | Enabled |
| teams | 23 | Enabled |

None of these tables has forced RLS. This is normal for ordinary Supabase API
access but means table owners/service roles bypass RLS and must remain
server-only.

Other catalogue totals:

- 44 public-table constraints.
- 40 public-table indexes.
- 9 public functions.
- 1 storage bucket.
- No deployed Supabase Edge Functions.
- No `supabase_migrations.schema_migrations` relation.

The absence of a migration-history relation strongly suggests that at least part
of the live schema was applied manually through saved SQL snippets rather than a
linked Supabase CLI migration workflow.

## Local reproducibility check

Docker Desktop 29.6.2, Docker Compose 5.3.1, and Supabase CLI 2.110.0 were
installed and verified on 30 July 2026. A clean `supabase start` downloaded the
local stack successfully, then failed while applying the first repository
migration:

- first migration: `202603141200_fix_forward_team_rls.sql`;
- failure: `team_memberships.player_id` references a missing `players` table;
- later migration `202603141330_multi_team_model.sql` assumes the same legacy
  core schema and recreates the permissive team policies that the earlier
  fix-forward migration attempts to remove.

IOS-002 subsequently added a reconstructed core migration before the legacy
fix-forward files. A clean local reset now applies all 16 migrations and passes
Supabase schema lint. Remote verification also exposed and corrected the
Supabase-hosted `extensions.gen_random_bytes` namespace difference.

## Staging environment

A separate Supabase project was created and verified healthy on 30 July 2026:

- name: `Roo Bin Staging`;
- project reference: `mwpmibgtqkhivarvcttw`;
- region: West EU (Ireland), `eu-west-1`;
- initial state: no application migrations, branches, or application data.

The database password and API keys remain outside the repository and this
document. This project is the target for IOS-002 migration and security tests;
production project `fnejcjhxngxfmksubwpe` must not be used for migration
experiments.

All 16 migration versions were applied to staging and verified against the
remote migration history. The staging schema passes Supabase lint. Its final
schema contains the authenticated-only `create_team_with_captain` and
`join_team_by_code` functions and no policy named `allow all`.

## Confirmed P0 policy drift

Postgres combines permissive policies with OR semantics. A restrictive-looking
team policy does not protect a table when another applicable policy grants broad
access.

### Anonymous full access to team administration tables

The following live policies use `USING (true) WITH CHECK (true)` for `public`:

- `teams.allow all`
- `team_memberships.allow all`
- `team_invites.allow all`

Impact:

- an unauthenticated API client may be able to read, create, update, or delete
  teams, memberships, and invites;
- the intended team-scoped policies do not compensate for the overlapping
  `allow all` policy;
- this can permit membership/role manipulation and cross-team information
  exposure.

The Supabase Security Advisor independently reports all three as “RLS Policy
Always True” warnings.

Repository comparison:

- `202603141330_multi_team_model.sql` creates these early permissive policies;
- `202603141200_fix_forward_team_rls.sql` intends to drop them;
- the live database still has them, so repository filename ordering/manual
  execution did not produce the intended final state.

### Authenticated full access to operational tables

The live database contains policies named `authenticated full access ...` on:

- `players`
- `fine_types`
- `seasons`
- `matches`
- `match_players`
- `fines`
- `subs`

Each applies to `public` and grants all operations whenever
`auth.role() = 'authenticated'`.

Impact:

- any signed-in user can bypass the narrower team policies through direct API
  calls;
- cross-team reads and mutations may be possible;
- client-side role checks do not provide a security boundary.

These policy names are not present in the repository migrations, confirming
untracked live drift.

### Public player enumeration

`players auth lookup` permits anonymous selection with `USING (true)`. This
supports the current pre-authentication lookup flow but exposes the player table
to enumeration. The anonymous registration insert policy also allows creation
of unlinked player rows.

Required replacement: a server-owned, non-enumerating identity completion flow
after OTP verification.

## Functions and grants

Live functions:

- `current_player_id` — SECURITY DEFINER
- `current_player_id_for_auth_user` — SECURITY DEFINER
- `generate_team_join_code`
- `is_admin_of_team`
- `is_member_of_team`
- `set_team_join_code`
- `set_updated_at`
- `sync_player_name_columns`
- `sync_player_profile_columns`

All nine functions are executable by `anon`, `authenticated`, and
`service_role`; most also retain default public execute.

Confirmed warnings:

- both SECURITY DEFINER identity helpers are executable without signing in;
- seven functions have a mutable/unset `search_path`;
- helper/trigger functions have broader execute grants than their intended use
  requires.

The Supabase Security Advisor reports 15 warnings in total: seven mutable search
paths, three always-true RLS policies, two publicly executable SECURITY DEFINER
functions, and three additional warnings not required to establish the current
P0 conclusion.

## Storage

Bucket: `team-logos`

- Public read access.
- Maximum object size: 1 MiB.
- Allowed MIME type: `image/webp`.

The storage-object write policy was not included in the `public`-schema policy
query. Repository migration `202607291500_team_sub_amount_logo.sql` contains a
team-leader storage write policy, but its live definition must be included in
the IOS-002 verification query before relying on it.

## Authentication configuration

Observed:

- New-user signup enabled.
- Email confirmation enabled.
- Manual identity linking disabled.
- Anonymous sign-in disabled.
- Email provider enabled.
- Phone provider enabled.
- All listed social providers, including Apple and Google, disabled.
- No custom OAuth/OIDC providers.

Rate limits:

- Email sends: 30 per hour for the project.
- SMS sends: 30 per hour for the project.
- Token refreshes: 150 per five minutes per IP.
- OTP/magic-link verifications: 30 per five minutes per IP.
- Signup/sign-in requests: 30 per five minutes per IP.
- IP forwarding disabled.

URL configuration:

- Site URL: `https://roobin-sigma.vercel.app/`
- Redirect URL allow-list: empty.

The Site URL is stale relative to the current public application at
`https://roobin.trovefinds.co.uk/`. This should be corrected through a planned
Auth configuration change, with the native app’s universal-link/custom callback
strategy added to the allow-list before iOS authentication testing.

## Edge Functions

No Edge Functions are deployed. Therefore there is currently no Supabase-hosted
server boundary for:

- identity completion/linking;
- unlock-code verification;
- protected mutations;
- account deletion;
- team invitation/notification delivery;
- transactional match aggregate writes.

These remain IOS-007 through IOS-011 dependencies.

## Drift classification

| Finding | Repository intended state | Live state | Severity |
|---|---|---|---|
| Team table `allow all` policies | Dropped by fix-forward migration | Present | P0 |
| Core authenticated-full-access policies | Not present | Present on seven tables | P0 |
| Anonymous player lookup | Present in later migration | Present | P1 redesign |
| SECURITY DEFINER public execute | Partially revoked for one helper only | Public/anon execute on both | P1 |
| Function search paths | Only selected helper fixed | Seven warnings | P1 |
| Migration provenance | Version-controlled migrations | No live history relation | P1 |
| Auth Site URL | Current production URL expected | Old Vercel URL | P1 |
| Native redirect URLs | Required before native auth | None | Planned |
| Edge Functions | Required target boundary | None deployed | Planned |
| Team logo bucket | Public WebP, 1 MiB | Matches latest web implementation | Product/security decision |

## Finding-to-story traceability

Every confirmed finding has an implementation story and a release gate.

| Live finding | Primary stories | Release gate |
|---|---|---|
| `allow all` policies on teams, memberships, and invites | IOS-002, IOS-006 | Blocks any production native write and external TestFlight |
| Authenticated full access on seven operational tables | IOS-002, IOS-006 | Blocks any production native write and external TestFlight |
| Anonymous player enumeration and unlinked registration | IOS-007, IOS-030, IOS-031 | Blocks native authentication release |
| Public SECURITY DEFINER execution and mutable search paths | IOS-006, IOS-008, IOS-012 | Blocks protected actions and external TestFlight |
| Client-side unlock verification/rate limiting | IOS-008, IOS-054, IOS-067 | Blocks protected native actions |
| Multi-request, non-atomic mutations | IOS-009, IOS-050–IOS-055, IOS-062–IOS-066 | Blocks operational write parity |
| No account deletion | IOS-011, IOS-073 | Blocks App Store submission |
| No migration provenance | IOS-002, IOS-012 | Blocks reproducible staging/production promotion |
| Stale Auth Site URL and empty redirect allow-list | IOS-012, IOS-030, IOS-036 | Blocks native authentication and invite links |
| No server/Edge Function boundary | IOS-007–IOS-012 | Blocks native production writes |
| Public logo lifecycle and format decision | IOS-005, IOS-061 | Blocks final privacy disclosure and logo parity |
| RackEm scraper contract/rights risk | IOS-004, IOS-070, IOS-071 | Blocks RackEm v1 release if retained |
| Dependency vulnerabilities and privacy governance | IOS-024, IOS-080, IOS-083 | Blocks release candidate sign-off |

The umbrella release rules in `IOS_BACKLOG.md` and
`APP_STORE_CHECKLIST.md` also state that unresolved P0/P1 findings block
external TestFlight and App Review.

## Dependency audit snapshot

An npm registry audit on 30 July 2026 reported six development/dependency-graph
findings: one low, one moderate, four high, and no critical findings.

- Direct dependencies: PostCSS and Vite.
- Transitive dependencies: Babel core, esbuild, picomatch, and `ws`.
- The available Vite remediation is a major upgrade, so it must not be applied
  through `npm audit fix --force` without compatibility work and regression
  testing.
- These packages are primarily in the web build/development toolchain, but the
  findings remain release engineering work under IOS-024 and IOS-080.

## Safe next step: IOS-002

Do not edit production policies directly from the dashboard as the next action.

1. Add a local Supabase configuration and install/pin the Supabase CLI.
2. Create a separate staging Supabase project.
3. Build a safe baseline migration from the repository plus this drift record.
4. Add automated RLS tests for anonymous, member, removed member,
   vice-captain, captain, platform admin, and cross-team access.
5. Write an idempotent production remediation migration that explicitly drops
   every known permissive policy and recreates the intended policies.
6. Test web authentication and all primary journeys against staging.
7. Back up production and apply the reviewed migration in a controlled window.
8. Rerun the catalogue queries and Supabase Security Advisor.

Production remediation requires a separate explicit execution decision after
the migration and staging evidence are reviewed.
