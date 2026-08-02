# RooBin paid-operation runbook

Status: implementation baseline  
Owner: product operations  
Review cadence: monthly and after every material incident

## Entitlement matrix

The published `fines-team-standard` definition is the single source for UI and
server enforcement. One purchased playing cycle covers League, Cup and Plate
seasons linked to that cycle.

| Capability | Team trial | Paid Team | Grace | Expired |
|---|---:|---:|---:|---:|
| View existing dashboard, matches, fines and subs | Yes | Yes | Yes | Yes |
| Create/update matches, fines and subs | Yes | Yes | Yes | No |
| Team and RackEm configuration | Yes | Yes | Yes | No |
| Privacy export, support and account deletion | Yes | Yes | Yes | Yes |
| Billing portal or next-cycle purchase (captain/billing contact) | Yes | Yes | Yes | Yes |

Access is authoritative only when the server capability check succeeds. League
and future products must publish another versioned definition; changing a
future definition never mutates an existing entitlement.

## Payment and entitlement response

1. Check Commercial Operations for failed provider events, reconciliation
   issues and access gaps. Never request a card number or team unlock code.
2. Compare provider event/reference, subscription, financial entry and
   entitlement. The verified provider is financial evidence; the RooBin audit
   log remains the historical control record.
3. Retry only replay-safe provider events. Use an audited correction with a
   detailed reason for an entitlement-only repair. Refunds remain provider-led
   and create immutable ledger adjustments.
4. For disputes, open an operator case, place access into the configured grace
   state, retain customer data, and resolve from the verified provider event.

## Service and support targets

- Public support receipt is immediate. Proposed targets pending owner approval:
  urgent acknowledgement within 4 working hours; normal within 2 working days.
- Status components cover web, API/authentication, iOS and transactional email;
  payments are added when live Stripe checkout is enabled.
- Incident updates state observed impact and mitigation without promising an
  unsupported availability SLA. Post-incident actions are operator cases.

## Backup and recovery

Production must enable Supabase point-in-time recovery or daily backups before
enforcement. Scope includes catalogue, prices, discounts, billing customers,
subscriptions, entitlements, financial entries, events, audit, support and
operator cases. Target baseline is RPO 24 hours and RTO 8 hours until a paid
hosting plan approves tighter objectives.

Quarterly, restore a backup into a non-production project, keep only sanitised
counts as evidence, then run reconciliation before permitting writes. Do not
replay provider money operations during a restore. Enforce mode stays off until
the restored entitlement and financial counts reconcile.

## Retention

| Record | Baseline |
|---|---|
| Financial, invoice, tax and commercial audit evidence | 7 years after the accounting period, subject to accountant/legal approval |
| Provider event full payload | 90 days, then minimise to event ID, type, status and safe evidence |
| Billing contact personal fields | Anonymise when no active obligation remains; preserve non-personal financial linkage |
| Support cases | 24 months after closure unless linked to an unresolved legal/financial case |
| Public rate-limit fingerprints | 24 hours |

Account deletion immediately removes the playing profile through the existing
journey. Commercial records that must be retained are access-restricted,
anonymised where possible and excluded from marketing. A production retention
job must run as an observable idempotent scheduled task; its run result belongs
in `commercial_retention_runs`.

## Capacity and cost review

Each month record Supabase database/storage/egress/MAU/email usage, Vercel
bandwidth/function usage, fixed and variable cost. Review cost per paid
team-season and set provider-console warnings at 70%, action at 85%, and urgent
at 95% of each plan limit. Production alert ownership and console evidence are
deferred in `COMMERCIAL_DEFERRED_ACTIONS.md`.
