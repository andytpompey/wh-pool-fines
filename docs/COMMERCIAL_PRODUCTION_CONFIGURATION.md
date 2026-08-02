# RooBin commercial production configuration

Status: deployment inventory
Updated: 2 August 2026

This is the value-free production inventory for the Paid Fines release. Never
paste secret values into this file, a story, Git, logs or chat. Record only the
secret name, owner, rotation date and verification evidence in the production
secret manager.

## Web application

Configure in Vercel and use the same production Supabase project referenced by
the Edge Functions:

| Variable | Purpose |
|---|---|
| `VITE_SUPABASE_URL` | Public production Supabase URL |
| `VITE_SUPABASE_ANON_KEY` | Public production anon/publishable key |

The assumed public origin is `https://roobin.trovefinds.co.uk`. Vercel rewrites
all SPA routes to `/index.html`; Supabase Auth must allow the exact production
`/auth/callback` URL.

## Supabase Edge Function secrets

Supabase provides `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
`SUPABASE_SERVICE_ROLE_KEY` to deployed functions. Confirm they refer to the
same project; never expose the service-role key to web or iOS clients.

| Secret/configuration | Used by | Verification |
|---|---|---|
| `PUBLIC_APP_ORIGIN` | checkout, portal, discounts, App Store, notifications and public support | Exact HTTPS production origin; no trailing path |
| `STRIPE_SECRET_KEY` | catalogue price binding, checkout, discounts, portal, webhook and reconciliation | Live or test mode deliberately selected |
| `STRIPE_WEBHOOK_SECRET` | commercial webhook | Matches the deployed endpoint only |
| `COMMERCIAL_CRON_SECRET` | notifications, reconciliation and lifecycle schedules | Random secret held by scheduler and functions only |
| `RESEND_API_KEY` | commercial and team notifications | Restricted production sending domain |
| `TEAM_EMAIL_FROM` | commercial and team notifications | Verified sender such as `RooBin <support@…>` |
| `APP_STORE_BUNDLE_ID` | App Store transaction verification | `com.roobin.app` |
| `APP_STORE_APP_APPLE_ID` | App Store transaction verification | Numeric App Store Connect application ID |
| `APP_STORE_ENVIRONMENT` | App Store transaction verification | `SANDBOX` during evidence testing, `PRODUCTION` for release |
| `APPLE_ROOT_CERTIFICATES_BASE64_JSON` | App Store JWS chain verification | Current trusted Apple roots encoded by the deployment procedure |
| `APP_ORIGIN` or `APP_PUBLIC_URL` | legacy team invitation link fallback | Set to the same production app origin until consolidated |

## Deployed functions and authentication boundary

| Function | Caller/authentication |
|---|---|
| `commercial-checkout` | Authenticated captain/vice-captain; server reloads catalogue price |
| `commercial-portal` | Recently authenticated billing authority |
| `commercial-catalogue-provider` | Platform administrator |
| `commercial-discounts` | Platform administrator |
| `commercial-webhook` | Stripe signature, not a user JWT |
| `app-store-transaction` | Authenticated app user plus verified signed transaction |
| `commercial-notifications` | `x-commercial-cron-secret` |
| `commercial-reconciliation` | `x-commercial-cron-secret` |
| `commercial-lifecycle` | `x-commercial-cron-secret`; preview unless mode is explicitly `apply` |
| `public-support` | Public request controls and honeypot |
| `account-deletion` | Authenticated account owner |
| `team-communications` | Authenticated team authority |

## Required schedules

Use independent schedules so one operational path cannot suppress another:

| Schedule | Initial cadence | Request |
|---|---|---|
| Notifications | Daily | `POST commercial-notifications` with cron header |
| Reconciliation | Daily | `POST commercial-reconciliation` with cron header |
| Retention preview | Before first apply and after policy changes | `POST commercial-lifecycle` with cron header and default/preview body |
| Retention apply | Approved retention cadence | `POST commercial-lifecycle` with cron header and `{"mode":"apply","policyVersion":"v1.0"}` |

Production values, provider-console setup, legal decisions and live evidence are
tracked in [`COMMERCIAL_DEFERRED_ACTIONS.md`](COMMERCIAL_DEFERRED_ACTIONS.md).
