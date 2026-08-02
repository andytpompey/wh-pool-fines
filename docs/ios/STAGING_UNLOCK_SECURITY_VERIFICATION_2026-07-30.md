# Staging Unlock Security Verification — 30 July 2026

Story: IOS-008  
Target: `Roo Bin Staging` (`mwpmibgtqkhivarvcttw`)  
Production changed: no

## Implemented

- Unlock codes are hashed with server-side bcrypt and never hashed or compared
  by the client.
- Authenticated clients have no SELECT privilege on `unlock_code_hash` or
  `unlock_code_salt`.
- Team creation and join RPCs return redacted JSON rather than the `teams`
  composite row.
- Verification is an authenticated SECURITY DEFINER operation with an empty
  search path.
- Only active captains and vice-captains can verify protected actions; ordinary
  members and platform administrators cannot.
- Attempt state is stored in a server-only table and locks an actor/team pair
  for five minutes after five failed attempts.
- Successful verification returns an opaque, action-specific grant expiring
  after 60 seconds.
- Success and failure are server-audited without code, hash, salt, or token
  values.
- Existing client-side PBKDF2 and localStorage rate-limit logic is removed.
- Existing version-1 hashes will be invalidated and require captain rotation
  when this migration is eventually approved for production.

## Evidence

- All 18 migrations apply from zero locally.
- Supabase local and staging schema lint: zero errors.
- All 18 versions are recorded on staging.
- Existing 17-case identity/authorization suite passes.
- New 10-case unlock suite passes:
  - hash and salt cannot be selected;
  - rate-limit state cannot be selected;
  - captain can set a server hash;
  - incorrect code is rejected;
  - correct code creates an opaque grant;
  - member verification is rejected;
  - durable rate limiting activates;
  - audit payloads contain no submitted code.
- Web production build passes.

## Grant consumption

The subsequent IOS-009 protected-mutation migration now consumes every grant in
the same transaction as its matching mutation and audit record. Replay,
wrong-action, and cross-team tests pass, completing IOS-008 on staging.

Captain recovery and platform-admin reset notification flows also need the
server-owned endpoint work in IOS-010.
