# Staging Protected Mutation Verification — 30 July 2026

Stories: IOS-008, IOS-009  
Target: `Roo Bin Staging` (`mwpmibgtqkhivarvcttw`)  
Production changed: no

## Implemented

- `execute_protected_action` consumes an authenticated actor's unexpired,
  action-specific grant in the same transaction as the mutation and audit row.
- Supported targets:
  - match deletion;
  - fine or sub deletion;
  - fine-type deletion;
  - season deletion;
  - non-captain/non-self membership removal;
  - submitted-match unlocking.
- A consumed token cannot be replayed.
- A token cannot be changed to another action, actor, or team.
- Direct RLS deletion is removed for protected tables.
- A database trigger blocks direct `submitted = true` to `false` transitions.
- The web client passes the opaque grant to the mutation RPC and no longer
  performs a separate client-side delete/audit sequence.
- Match aggregate updates now upsert fines and subs rather than deleting and
  recreating them, so ordinary editing does not require protected delete access.

## Evidence

- All 19 migrations apply locally from zero.
- Local and staging Supabase schema lint: zero errors.
- Web production build passes.
- The existing 17-case authorization and 10-case unlock suites pass.
- The 10-case protected-mutation suite passes:
  - direct delete denial;
  - direct match-unlock denial;
  - valid atomic mutation;
  - target deletion;
  - replay denial;
  - wrong-action denial;
  - cross-team denial and rollback;
  - grant-consuming match unlock;
  - resulting match state;
  - exactly one atomic audit record per successful mutation.

## Transactional domain operations

The final IOS-009 migration adds:

- `save_match_aggregate` for match, player/driver, fine, and sub changes in one
  transaction;
- protected-deletion detection so an aggregate save cannot remove fines/subs
  without an unlock grant;
- `transfer_team_captain` for one atomic demotion/promotion and audit;
- `update_payment_batch` for all-or-nothing fine/sub settlements;
- actor-scoped operation IDs and stored responses for safe retries.

Nine additional tests cover aggregate creation, idempotent retry, protected
deletion rollback, captain transfer, exactly-one-captain outcome, payment batch
commit, and payment retry. IOS-009 is complete on staging.
