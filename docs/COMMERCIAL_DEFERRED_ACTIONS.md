# Commercial deferred actions

Updated: 2 August 2026

## Local database reset notice

At approximately 13:20 BST on 2 August 2026, an attempted isolated fresh-schema
validation using `supabase db reset --db-url .../roobin_fresh_validation`
unexpectedly reset the normal local Supabase database when the CLI restarted
the local stack. All repository files and Git history are unaffected, and all
migrations replayed successfully. Any pre-reset data that existed only in the
local database is not recoverable from the current Docker volume; restore it
from a linked environment or external backup if it was needed. Do not run
another local reset. This notice must remain until the owner has reviewed it.

These actions need account ownership, legal/tax judgement or production-console
interaction. They do not block local implementation and tests. Evidence must be
added to the named story before it can move to Done.

| Story | Action for product owner | Where | Blocking point |
|---|---|---|---|
| COM-004 | Approve customer identity, cancellation/refund wording, read-only expiry baseline and legal operator details | Product/legal review | Before public paid launch |
| COM-005 | Update the separately hosted TroveFinds holding page with the approved independent-project wording and RooBin card; remove any purposeless mailing-list control | GoDaddy site editor | Before public RooBin launch |
| COM-006 | Production hostname and required HTTPS routes were verified on 2 August 2026. Complete authenticated sign-in/email and Stripe return journeys after deployment to verify provider callback configuration | Supabase, Stripe and production app | Before production callback sign-off |
| COM-007 | Deploy the approved commit to production and record the Vercel deployment URL and commit SHA | Vercel | Before public RooBin launch |
| COM-009 | Provide a public postal/service address for Andy Thomas trading as RooBin through TroveFinds, then confirm the updated policy/support routes on production | Product owner + production app | Before public paid launch |
| COM-020 | Create/verify the Stripe business account, enable GBP cards and wallets, and complete business verification | Stripe Dashboard | Before live checkout |
| COM-017 | From Commercial Operations, create the Stripe binding for the published GBP 10 price and confirm its amount/currency/tax mode in Stripe; do not copy provider IDs manually | Production app + Stripe Dashboard | Before live checkout |
| COM-021 | Add the deployed `commercial-webhook` endpoint and record the signing secret | Stripe Workbench | Before live payment fulfilment |
| COM-026 | Enable and configure Stripe Customer Portal policies | Stripe Dashboard | Before self-service payment-method changes |
| COM-041 | Accept Apple paid-app agreements, complete banking/tax, create the In-App Purchase product, price it at the closest approved GBP tier and provide sandbox accounts | App Store Connect | Before StoreKit end-to-end test |
| COM-055 | Review and approve the escalation wording in `COMMERCIAL_OPERATIONS_RUNBOOK.md`; `hello@trovefinds.co.uk`, a five-working-day response target and Andy Thomas as primary operator are recorded | Product owner | Before public launch |
| COM-056 | Review and approve the incident-owner wording in `COMMERCIAL_OPERATIONS_RUNBOOK.md`, then configure the production transactional-email channel and monitor delivery failures | Product owner + production secrets | Before production launch |
| COM-057 | Enable production backups/PITR and complete the first sanitised restore drill against the runbook | Supabase production + staging | Before entitlement enforcement |
| COM-050 | Configure Supabase and Vercel 70/85/95 percent usage and spending alerts; record the alert owner | Supabase and Vercel dashboards | Before production launch |
| COM-003 | Enter the first production monthly provider-usage and fixed-cost snapshot | Commercial Operations | At the end of the first live month |
| COM-013 | Configure the daily `commercial-notifications` schedule and `COMMERCIAL_CRON_SECRET`; send a monitored test reminder | Supabase scheduled function + production secrets | Before trial invitations |
| COM-015 | Select the founding teams, record the pre-pilot baseline and feedback dates in Commercial Operations, then capture committee/captain feedback and the explicit renew/do-not-renew outcome with reasons | Founding league + Commercial Operations | During and at the end of the pilot |
| COM-019 | Review the first live offering/version purchase, trial, renewal, cancellation and discount cohorts and attach the aggregate report evidence to the story | Commercial Operations | After the first live commercial cycle |
| COM-023 | Create the next playing cycle, complete a captain-led next-season purchase and verify the current and next-cycle entitlements remain distinct | Production app + payment provider | Before the first renewal window closes |
| COM-039 | Configure the daily `commercial-reconciliation` schedule with `COMMERCIAL_CRON_SECRET`, review its first operator cases and approve (do not auto-apply) any repairs | Supabase scheduled function + Stripe production | Before entitlement enforcement |
| COM-029 | Review the minimal-provider-impact refund policy draft in `COMMERCIAL_POLICY_DECISIONS.md`, obtain advice where needed, configure matching Customer Portal wording, then exercise partial refund and dispute closure | Product/legal + Stripe Dashboard | Before live refunds are delegated to support |
| COM-037 | Deliver transfer notices to both reachable parties, then run and evidence one normal dual-confirmed handover and one four-eyes recovery drill | Production app + notification provider | Before support may recover billing ownership |
| COM-058 | Review checkout, billing portal, App Store verification and support rate-limit counts after the pilot; record false positives and approve threshold changes | Production logs + Commercial Operations | During pilot, before enforcement |
| COM-024 | Confirm Stripe promotion codes are enabled and issue/redeem one production-mode penny-free test code before publishing a campaign | Stripe + Commercial Operations | Before advertising a discount |
| COM-007 | In a normal desktop browser, complete the production smoke journeys: public pricing to sign-in, team billing context, checkout return, billing portal return, support submission and status page navigation | Production web app | After deployment, before launch |
| COM-022 | Complete one live wallet/card checkout in Safari and verify the Stripe receipt, entitlement activation and success return page; repeat cancellation and declined-payment paths | Safari + Stripe live test mode | Before live payment fulfilment is signed off |
| COM-024 | Open the published pricing page in Safari and confirm an eligible promotion is visible and its Stripe checkout total matches the campaign terms | Safari + Stripe live test mode | Before advertising a discount |
| COM-041 | On a physical iPhone, purchase and restore the non-renewing season product with an App Store sandbox account; verify entitlement recovery after reinstall | iPhone + App Store Connect sandbox | Before App Store submission |
| COM-053 | Manually check the production public pages at 200 percent zoom and with keyboard-only navigation, then run VoiceOver over pricing, checkout return, billing and support journeys | Desktop/iPhone accessibility tools | Before public launch |
| COM-056 | Open the public status page during a test incident and confirm component state, incident wording and recovery update render correctly without signing in | Production status page | Before production launch |
| COM-059 | Schedule `commercial-lifecycle` independently from notifications using `COMMERCIAL_CRON_SECRET`; call preview mode first, review its recorded run, then approve `{"mode":"apply","policyVersion":"v1.0"}` and retain processor-side deletion evidence | Supabase scheduled function + processor consoles | Before the first retention deadline |

Browser checks are intentionally deferred to this list to conserve remote-session
tokens. Automated unit, database, build, bundle and HTTP-level checks remain part
of the implementation workflow.

Never paste Stripe, App Store, Supabase or email secrets into a story or chat.
Configure them directly in the relevant production secret store and record only
the secret name, owner, rotation date and verification evidence.
