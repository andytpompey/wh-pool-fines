# Staging Security Verification — 30 July 2026

Stories: IOS-006, IOS-007  
Target: `Roo Bin Staging` (`mwpmibgtqkhivarvcttw`)  
Production changed: no

## Implemented

- `ensure_current_player` links or creates a player only after Supabase
  authentication and derives linkable email/phone identity from `auth.users`.
- Anonymous player enumeration and anonymous player registration policies are
  removed.
- Identity linking is a SECURITY DEFINER transaction with an empty search path,
  authenticated-only execute grant, canonical `players.user_id`, row locking,
  and unique-conflict rejection.
- `app_users` no longer permits users to update their own
  `is_platform_admin` entitlement.
- Team reads are limited to members or platform administrators.
- Operational writes to fine types, seasons, matches, match players, fines, and
  subs require captain, vice-captain, or platform-administrator authority.
- Captain-only membership administration remains enforced independently.
- Explicit authenticated table grants make clean installs behave like hosted
  Supabase projects while RLS remains the row/operation decision point.

## Evidence

- All 17 local migration versions apply from an empty database.
- Supabase local schema lint: zero errors.
- Seventeen pgTAP authorization tests pass:
  - captain operational authorization;
  - captain direct database write;
  - member operational denial;
  - member direct-write RLS denial;
  - cross-team read denial;
  - cross-team mutation denial;
  - vice-captain operational authorization and write;
  - vice-captain role-change denial;
  - invited-member denial;
  - removed-member denial;
  - platform-administrator read and operational write;
  - verified identity matching;
  - canonical auth-user linkage;
  - conflicting identity takeover denial;
  - anonymous identity-RPC denial.
- All 17 versions are recorded on staging.
- Supabase staging schema lint: zero errors.
- Staging schema dump contains none of:
  - `allow all`;
  - `authenticated full access`;
  - `players auth lookup`;
  - `players registration insert`.
- Web production build passes.

## Identity compatibility removal plan

`players.user_id` is canonical now. `players.auth_user_id` remains a
trigger-synchronised compatibility alias for the existing web build. Remove it
only after:

1. production web and native clients use `user_id` exclusively;
2. production has no rows where the two values differ;
3. one release has operated without compatibility-column reads or writes;
4. a reversible production migration has been rehearsed on staging.

With this plan and the 17-case matrix, IOS-006 and IOS-007 acceptance is
complete on staging. Production rollout remains a separate controlled change.

The current WhatsApp webhook verifies a code but does not return a Supabase
session. It therefore cannot use the authenticated identity-linking function
safely. Email OTP is the verified staging path; the server-owned WhatsApp
session contract remains part of IOS-010 and must be completed before WhatsApp
is enabled in either native or hardened web authentication.
