# Privacy and Retention Baseline

Status: owner approved 2 August 2026; external legal review remains advisable  
Reviewed: 2 August 2026

## Principles

Collect only data required for account, team and match operation. Do not add
advertising, cross-app tracking, contact-book access, location, microphone, or
behavioural analytics in v1. Keep secrets out of logs and retain operational
records only for an approved purpose.

## Data inventory and proposed handling

| Data | Purpose | Processor/store | Proposed lifecycle |
|---|---|---|---|
| Auth identity, email and provider IDs | sign-in and recovery | Supabase Auth; Apple/Google when used | delete with account after obligations resolve |
| Player display name and preferences | team identity and UX | Supabase Postgres | delete with account; historical ledger snapshots receive a random team-specific sport alias |
| Team membership and role | authorisation and history | Supabase Postgres | remove access immediately; retain anonymised historic attribution |
| Matches, fines, subs and payments | shared team ledger | Supabase Postgres | team-owned record; anonymise deleted player identity while preserving amounts |
| Invitations | team onboarding | Supabase, Resend | expire after 7 days; purge expired/revoked token material on a scheduled basis |
| Team logo | team branding | Supabase Storage | delete on replacement or team deletion after recovery window |
| Unlock verifier, grants and attempts | protected actions and abuse prevention | Supabase Postgres | never client-readable; grants expire in 60 seconds; retain attempts only for security window |
| Audit events | integrity, support and abuse investigation | Supabase Postgres | 12 months, then delete or irreversibly aggregate |
| Operational logs | reliability and security | Supabase/Vercel/provider logs | 30 days; redact tokens, OTPs, codes, recipients and payloads |
| RackEm public fixture data | match import | RackEm source, server and Postgres | retain imported team records; record provenance and refresh time |
| Email delivery metadata | invitations and security notices | Resend | provider minimum necessary; align provider retention with published policy |
| Device cache | performance | iPhone local storage | bounded; purge on sign-out, deletion, identity change or membership removal |

WhatsApp/SMS is deferred and must not appear in the production privacy inventory
unless a provider is approved and the feature is actually shipped.

## Account deletion baseline

- Require a recent authenticated session and explicit confirmation.
- Require captaincy transfer when another active team member remains. If the
  deleting captain is the only active member, close and permanently delete that
  team and its history with the account.
- Revoke sessions and provider tokens.
- Delete the Supabase Auth identity and direct personal profile data.
- Remove player references required to preserve the team’s historic ledger and
  replace snapshot names with one random sport-themed alias per team. The alias
  is stable inside that team but cannot link the former user across teams.
- Revoke pending invites issued solely for the deleted identity.
- Purge user-scoped device cache immediately.
- Make repeated deletion requests safe and report queued/completed status.

## Approved owner decisions

- Public data-controller identity: `Andy Thomas, operator of RooBin`.
- Operational logs: 30 days.
- Security audit records: 12 months.
- Account deletion is immediate, with no recovery period.
- RackEm wording: public fixture information is imported from publicly available
  RackEm pages at a team administrator's request; RooBin is not affiliated with
  RackEm.
