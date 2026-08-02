# Commercial deferred actions

Updated: 2 August 2026

These actions need account ownership, legal/tax judgement or production-console
interaction. They do not block local implementation and tests. Evidence must be
added to the named story before it can move to Done.

| Story | Action for product owner | Where | Blocking point |
|---|---|---|---|
| COM-004 | Approve customer identity, cancellation/refund wording, read-only expiry baseline and legal operator details | Product/legal review | Before public paid launch |
| COM-006 | Confirm production hostname (`roobin.trovefinds.co.uk` with `/app` is the implementation assumption), then preserve mail records while adding Vercel DNS | GoDaddy and Vercel | Before production callback verification |
| COM-008 | Decide whether a founding-league offer will be published; standard GBP 10 pricing does not depend on it | Product decision | Before advertising a trial |
| COM-020 | Create/verify the Stripe business account, enable GBP cards and wallets, and complete business verification | Stripe Dashboard | Before live checkout |
| COM-020 | Create Stripe product/price references matching the published RooBin catalogue and add the reference to `provider_price_refs.stripe` | Stripe Dashboard + production database via audited admin flow | Before live checkout |
| COM-021 | Add the deployed `commercial-webhook` endpoint and record the signing secret | Stripe Workbench | Before live payment fulfilment |
| COM-026 | Enable and configure Stripe Customer Portal policies | Stripe Dashboard | Before self-service payment-method changes |
| COM-038 | Confirm VAT status, customer market and whether Stripe Tax should collect inclusive or exclusive tax | Accountant/product owner | Before live charge |
| COM-040 | Recheck App Review 3.1 rules for the UK storefront and approve non-renewing StoreKit product mapping | Apple policy review | Before App Store submission |
| COM-041 | Accept Apple paid-app agreements, complete banking/tax, create the In-App Purchase product, price it at the closest approved GBP tier and provide sandbox accounts | App Store Connect | Before StoreKit end-to-end test |
| COM-055 | Approve the support mailbox, response target and escalation owner | Product operations | Before public launch |
| COM-056 | Select status-page provider/hostname and incident owner | Product operations | Before production launch |
| COM-057 | Enable production backups/PITR and complete the first sanitised restore drill against the runbook | Supabase production + staging | Before entitlement enforcement |
| COM-050 | Configure Supabase and Vercel 70/85/95 percent usage and spending alerts; record the alert owner | Supabase and Vercel dashboards | Before production launch |
| COM-003 | Enter the first production monthly provider-usage and fixed-cost snapshot | Commercial Operations | At the end of the first live month |

Never paste Stripe, App Store, Supabase or email secrets into a story or chat.
Configure them directly in the relevant production secret store and record only
the secret name, owner, rotation date and verification evidence.
