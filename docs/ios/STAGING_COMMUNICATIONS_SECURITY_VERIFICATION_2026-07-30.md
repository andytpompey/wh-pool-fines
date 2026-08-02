# Staging communications security verification — 2026-07-30

## Result

IOS-010 application and backend hardening is deployed to staging project
`mwpmibgtqkhivarvcttw`. Production was not changed.

Provider-dependent delivery is deliberately fail-closed:

- invites are recorded with a seven-day expiry and report that email delivery
  is disabled when transactional-email secrets are absent;
- unlock-code recovery refuses to rotate the code unless delivery is configured;
- WhatsApp OTP uses Supabase Auth's native WhatsApp channel so successful
  verification returns the same Supabase session used by RLS and identity linking.

## Security properties

- `team-communications` requires and independently verifies a Supabase access
  token.
- The browser submits only the requested action and minimal target identifier or
  invite input.
- The server resolves the actor, role, team, player and notification recipients.
- Invite tokens and unlock codes are generated server-side.
- Secret-bearing preparation RPCs are executable only by `service_role`.
- Invite resend rotates the token, immediately invalidating the old link.
- Invites expire after seven days.
- Invite sends are limited to 10 per actor/team/hour; unlock resets to 3 per
  actor/team/hour.
- Unlock recovery requires a session issued within the prior 10 minutes.
- The function logs only a generic error name, never request bodies, recipient
  lists, OTPs, tokens or unlock codes.

## Verification performed

- clean local database rebuild with all 22 migrations;
- 56 database security and transaction tests passed, including 10 communications
  cases;
- production web build passed;
- obsolete browser-owned endpoint environment variables and token generation
  were removed;
- migrations `202607302300` and `202607302330` deployed to staging;
- `team-communications` Edge Function deployed to staging.

## Provider configuration gate

Configure secrets in the staging Supabase project, not in source control:

- `RESEND_API_KEY`
- `TEAM_EMAIL_FROM`
- `APP_PUBLIC_URL`
- `APP_ORIGIN`

Configure the Twilio WhatsApp provider under Supabase Authentication phone
provider settings. Never place Twilio or Resend secrets in `VITE_*` variables,
the repository, an iOS bundle, or chat.

After configuration, run a real-device staging acceptance pass for email invite,
invite resend, email recovery, WhatsApp sign-in and WhatsApp recovery before any
production promotion.
