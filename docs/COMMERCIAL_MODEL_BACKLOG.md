# RooBin Commercial Model Backlog

Status: proposed product backlog  
Updated: 2 August 2026  
Story IDs are stable references; they do not imply repository issue numbers.

## Agreed commercial baseline

- The initial proposed Team offer is **GBP 10 per team per season**, maintained
  through the commercial catalogue rather than application code.
- A captain or league administrator pays; ordinary players do not need their
  own subscriptions.
- A season means one normal team playing cycle. League and cup competitions
  within that cycle do not create separate charges.
- Pool and darts teams can use the same platform, but sport, team, season and
  entitlement remain explicit data rather than pricing assumptions.
- League-wide access can use the number of participating teams as a billable
  quantity when the selected subscription model requires it.
- Prices, discounts, trial periods and tax treatment must be configured rather
  than hard-coded into a client.
- Commercial enforcement is server-owned. Web, iOS and future Android clients
  display the same authoritative entitlement state.

## Decisions still required

- Whether one pub or club operating both pool and darts teams receives a venue
  bundle or pays for each team separately.
- Whether the normal two-season advance price is GBP 20 or a discounted annual
  price.
- Whether the founding league trial is free for one division, discounted for
  the whole league, or both in sequence.
- Read-only expiry is the implementation baseline; any future limited-entry
  exception requires a separately versioned policy decision.
- Whether league invoices are collected through online card payment, bank
  transfer, or both.
- VAT registration and tax-display requirements at the point RooBin reaches
  the applicable threshold or uses a merchant-of-record arrangement.

## Working rules

- Existing team data is never deleted merely because paid access expires.
- Raw personal-data access, account deletion and legally required exports are
  never paywalled.
- Clients never decide entitlement from cached price or payment data alone.
- Payment webhooks and administrative grants are idempotent and audited.
- A failed renewal cannot silently leave a team appearing paid.
- App Store and Google Play purchasing rules are rechecked before implementing
  or submitting native purchase flows.
- Every commercial story includes web compatibility and backend security
  evidence where relevant.

## Increment 0 — Commercial decisions and measurement

### Epic C0 — Product and pricing foundation

#### COM-001 — Define the commercial catalogue

Status: complete — versioned catalogue, entitlement definitions and the published GBP 10 offer are implemented in migrations `202608021200` through `202608021320`; administration is server-authorised and audited.

As the product owner, I need a versioned catalogue of plans and prices so that
RooBin can offer GBP 10 team-season access without embedding commercial rules
in application code.

Acceptance:

- The catalogue supports product, offering, currency, tax behaviour, billing
  interval, billing unit, sport applicability, effective dates and
  active/inactive state.
- Supported billing units can include team-season, team-year, organisation-
  year, venue-year and a configured quantity-based league subscription without
  requiring a client release.
- GBP 10 per team per season is represented as the initial standard offer.
- League, founding-trial, promotional and complimentary offers can reference
  the standard product without changing historical purchases.
- Each offering identifies its included capabilities through versioned
  entitlement definitions.
- Minimum/maximum quantity, trial eligibility, renewal behaviour and allowed
  sales channels are configurable attributes.
- A price change does not alter an existing paid entitlement.
- Only authorised platform administrators can change the catalogue.

#### COM-002 — Define the paid season boundary

Status: complete — `team_playing_cycles` provides the stable paid boundary shared by League, Cup and Plate, with compatibility backfill and cycle-based entitlement tests.

As a captain, I need to understand exactly what one purchase covers so that I
am not unexpectedly charged for League and Cup records in the same cycle.

Acceptance:

- A paid period identifies one team, sport and season/cycle.
- League, cup and plate competitions can sit within one paid cycle.
- The product can represent two cycles in one calendar year.
- Pool and darts data remain separately identifiable.
- Changing a season name or source identifier does not create another charge.
- Cancellation, abandoned seasons and team transfers have recorded policies.

#### COM-003 — Establish the unit-economics dashboard

Status: in progress — commercial ledgers, monthly metrics and provider-usage/cost capture are implemented; the first live monthly provider snapshot remains a production action.

As the product owner, I need revenue and cost metrics per active team-season so
that introductory pricing can be reviewed using evidence.

Acceptance:

- Metrics include trials, paid team-seasons, active teams, active players,
  conversion, renewal, gross revenue, refunds and payment fees.
- Supabase database, storage, egress, MAU and email usage are captured monthly.
- Vercel usage and fixed platform costs can be entered or imported.
- Reports distinguish direct, app-store, league-invoice and complimentary
  access.
- No fine descriptions, payment secrets or unnecessary player data enter
  commercial analytics.

#### COM-004 — Approve commercial terms and customer ownership

Status: in progress — implemented terms, privacy, processor and expiry baselines are documented and published locally; operator identity and legal/tax approval remain recorded in `COMMERCIAL_DEFERRED_ACTIONS.md`.

As a buyer, I need clear purchasing and cancellation terms so that I know who
is paying, what happens on expiry and how support or refunds work.

Acceptance:

- The contracting customer is identified as captain, team, league, club or
  venue as appropriate.
- Terms cover price, duration, renewal, cancellation, refunds, tax and service
  availability.
- Privacy documents identify payment, email, hosting and analytics processors.
- The purchaser can access receipts and the current entitlement state.
- Account deletion and statutory data access remain available after expiry.

### Epic C0A — Public website and support presence

#### COM-005 — Refresh the TroveFinds holding site

Status: in progress — RooBin proposition and destination are ready, but the separately hosted TroveFinds site requires owner access and is recorded as an external publishing action.

As the owner of TroveFinds, I need the main site to explain that it is an
umbrella for independent projects so that RooBin can inherit appropriate trust
without making the holding site into another application.

Acceptance:

- `trovefinds.co.uk` remains a lightweight GoDaddy-hosted holding site.
- The proposition describes independent digital products and experiments
  rather than implying that TroveFinds is an active retail shop.
- An accessible project list distinguishes active, pilot, in-development and
  archived projects without publishing dead links.
- RooBin has a short, accurate card linking to its public site.
- Owner/contact, copyright, privacy and necessary cookie information are
  current.
- The mailing-list control is removed unless there is an approved purpose,
  audience, processor and communication plan for it.

#### COM-006 — Establish RooBin public routing on Vercel

Status: in progress — `/app`, direct SPA rewrites, auth/legal routes and production metadata are implemented; DNS, certificate and production callback verification require the owner consoles.

As a prospective customer, I need a stable RooBin address so that I can learn
about the product and open the application without navigating the TroveFinds
holding site.

Acceptance:

- The RooBin public site and web application are hosted on Vercel.
- The initial approved structure uses either `/app` or an `app` subdomain and
  records the decision before links are published.
- GoDaddy DNS points only the required RooBin host records to Vercel.
- Existing MX, SPF, DKIM, DMARC and service-verification records are preserved.
- Vercel provisions a valid certificate and redirects HTTP to HTTPS.
- Authentication callbacks, email links, direct SPA routes and account-deletion
  links work on the production hostname.
- Staging and preview deployments are not indexed as the production site.

#### COM-007 — Publish the RooBin proposition

Status: in progress — all required public routes, responsive journeys, canonical/social metadata and branding are implemented and browser-checked locally; production publication remains outstanding.

As a captain or league committee member, I need to understand RooBin before
creating an account so that I can decide whether it solves our fines and subs
problem.

Acceptance:

- Public routes include Home, How it works and Leagues.
- Content explains the captain, player and league journeys in plain language.
- Pool is represented accurately and darts is described only to the extent
  currently supported or clearly labelled as planned.
- Screenshots contain no real private team, player, fine or payment data.
- Primary actions distinguish starting a team, opening RooBin and enquiring
  about a league pilot.
- Pages are responsive, keyboard accessible and usable at supported text sizes.
- Metadata, canonical URLs, social previews, favicon and RooBin branding are
  consistent.

#### COM-008 — Publish pricing and the founding-league offer

Status: in progress — catalogue-driven Team pricing, paid-cycle explanation and minimal league enquiry are implemented; no founding offer will be advertised until its eligibility is approved.

As a buyer, I need transparent pricing and trial information so that I can
understand the commitment before contacting RooBin or starting checkout.

Acceptance:

- Pricing states the standard GBP 10 per team per season offer.
- The definition of a paid season explains how League, Cup and Plate
  competitions are treated.
- Illustrative league totals are clearly labelled and calculated from the
  current commercial catalogue rather than duplicated client constants.
- Any founding trial or discount displays eligibility, duration, normal price
  and what happens at the end.
- Pool/darts, annual and venue-bundle claims are omitted until their pricing
  decisions are approved.
- A league enquiry captures only the minimum contact, league and approximate
  team-count information required for follow-up.
- Successful submission, delivery failure, consent and abuse protection are
  handled without exposing internal addresses or credentials.

#### COM-009 — Provide the public support and policy hub

Status: in progress — help, contact, privacy, terms, deletion and support case intake are implemented; final operator details and production availability evidence remain external gates.

As a user or store reviewer, I need public support and policy information so
that help, privacy and account-management obligations remain available without
signing in.

Acceptance:

- Public routes include Help, Contact Support, Privacy, Terms and Account
  Deletion.
- Help covers joining a team, captain responsibilities, seasons, RackEm import,
  paid access, renewal and expiry at the level supported by the release.
- Contact Support confirms receipt, publishes expected response handling and
  avoids collecting unlock codes or unnecessary fine/payment data.
- Privacy and terms identify the real owner, contact route, processors and
  effective date.
- Account-deletion instructions match the implemented web and native journeys.
- Support, privacy and deletion URLs are suitable for App Store and Google Play
  metadata and remain accessible during an application outage where practical.
- Page owners and a review cadence are recorded so legal and support content
  does not silently become stale.

### Epic C0B — Commercial offering administration

#### COM-016 — Manage subscription offerings

Status: complete — restricted audited create, clone, full-field draft update, publish and retire workflows are implemented in the administration surface; published versions are immutable and the workflow is database-tested.

As a platform owner, I need to create and maintain subscription offerings so
that RooBin can change its commercial structure without code changes or direct
database editing.

Acceptance:

- An authorised platform administrator can create, clone, edit, retire and
  inspect an offering.
- Required fields include product, customer type, billing unit, interval,
  currency, tax behaviour, base price, quantity rules, included entitlements,
  renewal behaviour and sales channels.
- Validation prevents incomplete, contradictory or unsupported combinations.
- Draft offerings cannot be purchased or exposed publicly.
- Publishing records the approver, timestamp and immutable published version.
- Retiring an offering prevents new purchases without changing existing
  subscriptions or historical invoices.
- Administrative access is least-privilege and every mutation is audited.

#### COM-017 — Schedule and version base prices

Status: in progress — immutable effective-dated price scheduling, overlap rejection and existing-purchase treatment are implemented; provider-price synchronisation and production preview remain.

As a platform owner, I need to change an offering's base price safely so that
future customers receive the new price without rewriting existing commercial
history.

Acceptance:

- A price version records amount, currency, tax behaviour, effective start and
  optional end date.
- Administrators can schedule a future price and preview affected public and
  checkout displays.
- Published and previously charged price versions are immutable.
- Overlapping active price versions for the same offering and market are
  rejected.
- Existing-subscription treatment is explicit: retain, migrate at renewal or
  require customer acceptance.
- A rollback creates another version; it does not delete financial history.

#### COM-018 — Configure offering eligibility and trials

Status: complete — versioned eligibility/trial rules, controlled batch grants, a shared server-side eligibility evaluator and repeat-trial protection are implemented and database-tested.

As a platform owner, I need configurable eligibility rules so that introductory
and targeted offers are applied consistently.

Acceptance:

- Eligibility can reference customer type, product, sport, sales channel,
  geography where approved, first purchase, previous trial and effective date.
- Trial length, trial entitlement, payment-method requirement and conversion
  behaviour are explicit.
- Eligibility is evaluated server-side and returns a stable reason when an
  offer is unavailable.
- Repeated identities, teams or organisations cannot obtain unintended repeat
  trials through normal account changes.
- An authorised complimentary grant remains distinct from a customer trial.

#### COM-019 — Audit and report commercial catalogue activity

Status: in progress — restricted catalogue, discount, financial, reconciliation and unit-economics reports plus immutable audits are implemented; live renewal/cancellation cohort evidence remains.

As a platform owner, I need to understand how offerings and discounts are being
used so that pricing decisions and misuse can be investigated.

Acceptance:

- Reports cover purchases, active subscriptions, trials, discounts, redemption
  rate, gross discount value, renewal and cancellation by offering/version.
- Catalogue publication, retirement, manual override and discount issuance are
  included in an immutable administrative audit trail.
- Reports distinguish base price, discount, tax, processor fee, refund and net
  revenue.
- Access is restricted to authorised commercial roles.
- Reports contain no unnecessary fine, message or player-profile content.

## Increment 1 — Founding-league pilot

### Epic C1 — Entitlements and controlled trial access

#### COM-010 — Store team-season entitlements

Status: complete — authoritative playing-cycle entitlements, full lifecycle states, duplicate constraints, membership-independent access and provider/admin provenance are implemented and tested.

As RooBin, I need an authoritative team-season entitlement so that access does
not depend on who happens to be signed in or which client they use.

Acceptance:

- An entitlement records team, sport, covered cycle, offer, status, source,
  start, expiry and audit provenance.
- Supported states include pending, trial, active, grace, expired, cancelled,
  refunded and complimentary.
- A captain payment grants access to every authorised member of that team.
- Membership removal does not transfer purchasing authority or entitlement.
- Constraints prevent overlapping or duplicate grants from a retried action.

#### COM-011 — Enforce entitlements on the server

Status: complete — server triggers and RLS-backed capability checks enforce observe/enforce policy with stable errors; trial, covered and uncovered mutation tests pass.

As the product owner, I need paid capabilities enforced by the backend so that
modified or outdated clients cannot bypass the commercial model.

Acceptance:

- Protected mutations verify membership, role and entitlement server-side.
- Read and write behaviour for trial, active, grace and expired states is
  explicitly tested.
- The backend returns stable commercial error categories without exposing
  payment details.
- Web and native clients cannot self-grant, extend or transfer access.
- Cached entitlement can improve display speed but cannot authorise a write.

#### COM-012 — Grant a controlled founding trial

Status: in progress — idempotent previewable batch grants for selected playing cycles are implemented and audited; league/division selection awaits the League data model.

As a platform administrator, I need to grant a time-bounded pilot to selected
teams or a complete league so that RooBin can be evaluated before self-service
billing exists.

Acceptance:

- A grant can target one team, a selected division or all teams in a league.
- The grant records the agreed price, discount, start, end, owner and reason.
- All eligible teams in a selected league can be activated in one idempotent
  operation regardless of the league's current team count.
- Preview shows affected teams and exclusions before confirmation.
- Every grant, extension and revocation is audited.
- Complimentary access is reported separately from paid revenue.

#### COM-013 — Show trial and paid status to captains

Status: in progress — web and iOS team-cycle status, purchaser identity, configurable captain/billing-contact reminders and distinct payment-failure versus awaiting-activation copy are implemented; production delivery evidence remains.

As a captain, I need a clear access-status screen so that I know what is
included, when it ends and what action is required.

Acceptance:

- Team Settings shows trial/paid state, covered season, price, purchaser and
  expiry date.
- Members can see a non-disruptive status but are not asked to purchase access.
- Captains receive advance expiry notices using configurable intervals.
- The interface distinguishes awaiting league activation from payment failure.
- Price and status copy is consistent on web and iOS.

#### COM-014 — Handle expiry without losing team data

Status: complete — data-preserving read-only expiry, grace recovery, non-duplicating cycle purchase and statutory account journeys are implemented server-side and documented.

As an expired team, we need predictable restricted access so that historical
records and personal-data rights are preserved.

Acceptance:

- The approved expired-access policy is implemented consistently by the
  backend and clients.
- Existing data is retained according to the approved retention policy.
- No renewal attempt creates duplicate seasons, teams or payments.
- Captains can renew and recover normal access without support intervention.
- Required account deletion and data-access journeys remain available.

#### COM-015 — Capture founding-league feedback and conversion

Status: in progress — privacy-safe commercial and support measures exist, but baseline, scheduled participant feedback and an actual pilot outcome require the founding league.

As the product owner, I need an agreed pilot evaluation so that a discounted
trial produces a reliable renewal decision.

Acceptance:

- Baseline measures are recorded before the pilot.
- Adoption is reported by division, team, captain and match week without
  exposing private fine content.
- The league committee and a representative captain group have scheduled
  feedback points.
- Success measures cover activated teams, matches recorded, active members,
  captain time saved, support demand and stated willingness to renew.
- Renewal outcome and reasons are recorded at the end of the cycle.

## Increment 2 — Direct team checkout

### Epic C2 — Web payments and renewals

#### COM-020 — Purchase GBP 10 team-season access

Status: in progress — leadership-only catalogue-owned Stripe checkout and StoreKit initiation are implemented with duplicate protection; live provider configuration and end-to-end payment evidence remain.

As a captain, I need to purchase access for my team so that all team members can
use paid RooBin capabilities for the selected season.

Acceptance:

- Only an authorised captain can initiate a team purchase.
- Checkout shows team, sport, season, duration, total price, tax treatment and
  renewal behaviour before payment.
- The server creates the checkout from the current catalogue; clients cannot
  submit their own price.
- A successful confirmed payment activates exactly one entitlement.
- Abandoned, failed and duplicate attempts do not grant access.

#### COM-021 — Process payment events idempotently

Status: in progress — Stripe signature verification, App Store signed-transaction verification, replay ledgers and explicit lifecycle transitions are implemented; production webhook evidence remains.

As RooBin, I need verified payment-provider events to drive entitlement so that
redirects, retries and forged requests cannot create paid access.

Acceptance:

- Webhook signatures are verified server-side.
- Provider event IDs and payment references are unique and replay-safe.
- Activation, refund, dispute and cancellation events update entitlement using
  explicit state transitions.
- A committed payment is recoverable when the client loses connectivity.
- Secrets and full payment instrument details never enter clients or logs.

#### COM-022 — Issue receipts and reconcile revenue

Status: in progress — receipt references, separated gross/discount/tax/fee/net ledger and reconciliation issue reporting are implemented; accounting export and live settlement evidence remain.

As the product owner, I need payment reconciliation so that paid access, cash
received, fees, refunds and accounting records agree.

Acceptance:

- Purchasers receive or can retrieve a receipt/invoice reference.
- Reconciliation identifies payment without entitlement, entitlement without
  payment, duplicated events, refunds and disputes.
- Gross, processor fee, tax and net amounts are stored separately.
- Reports can be exported for accounting without exporting team fine data.

#### COM-023 — Renew or purchase the next season

Status: in progress — captains can retain the team and buy a distinct upcoming playing cycle without duplicate purchase; production reminder and purchase evidence remain.

As a captain, I need a simple renewal path so that the next playing cycle can
start without recreating my team.

Acceptance:

- A captain can select an existing or newly created upcoming cycle.
- Renewal retains the team, roster and allowed configuration while keeping
  historical season records stable.
- Renewal reminders do not target ordinary members as buyers.
- Manual renewal is supported before auto-renewal is introduced.
- The system prevents accidental purchase of the same cycle twice.

#### COM-024 — Create, issue and redeem discount codes

Status: in progress — audited fixed/percentage discounts, one-time Stripe codes, safe digest storage and verified redemption reconciliation are implemented; production-mode redemption evidence remains.

As the platform owner, I need to create and issue controlled discount codes so
that a customer can receive an approved reduction without changing the
offering's base price.

Acceptance:

- A discount supports fixed amount or percentage, currency where applicable,
  validity window, duration, total redemption limit and per-customer limit.
- Eligibility can be scoped to products, offerings, billing units, customer
  types, sales channels and approved customers/organisations.
- Administrators can issue a human-entered code, generate unique single-use
  codes or attach an approved discount directly to a quote.
- Code comparison is case-normalised, codes are stored safely, and generated
  values cannot be enumerated through public responses.
- Stacking is prohibited by default and allowed only through an explicit
  compatible-discount rule.
- The applied promotion and undiscounted price are recorded on the purchase.
- Redemption is enforced server-side and is concurrency-safe.
- Expired or ineligible codes do not reveal private league/team information.
- Revocation stops future redemption without altering completed purchases.
- Issuance, redemption, failed attempts, revocation and manual overrides are
  audited and included in commercial reporting.

#### COM-025 — Manage the billing customer and payer

Status: complete — billing identity, address, tax/contact data and protected provider references are separate from playing records; recent-authenticated audited profile, verified contact grant/removal and dual-confirmed ownership transfer are implemented without changing team authority.

As a purchaser, I need my billing identity kept separately from my playing
profile so that team or organisation purchases remain valid when roles change.

Acceptance:

- A billing customer can represent an individual, team, league, club, venue or
  legal organisation.
- Billing name, address, contact, tax identifiers and provider customer ID are
  stored with appropriate access controls.
- A verified user can be granted or removed as a billing contact without
  transferring team or league operational authority.
- Changing captain or league administrator does not silently cancel, transfer
  or expose a subscription.
- Sensitive billing changes require recent authentication and are audited.

#### COM-026 — Manage payment methods securely

Status: in progress — authenticated billing-owner Stripe Portal is implemented without RooBin handling instruments; production portal policy and journey verification remain.

As a billing contact, I need to add or replace the subscription payment method
so that renewals do not require RooBin to handle card data.

Acceptance:

- Card and wallet details are collected by the approved payment provider.
- RooBin stores provider references and safe display metadata only.
- A customer portal or equivalent flow supports replacing an expiring or failed
  payment method.
- Payment-method changes require authenticated billing-customer authority.
- Client logs, analytics and support tools never expose full payment details.

#### COM-027 — Renew a subscription automatically

Status: in progress — catalogue supports consented fixed-interval automatic offerings and idempotent Stripe renewal events while Team season stays manual; full advance auto-renew notice and live recurring test remain.

As a billing customer, I need predictable renewal so that paid access continues
without recreating the team or organisation.

Acceptance:

- Auto-renewal is enabled only when the offering, channel and customer consent
  permit it.
- Renewal uses the subscription's approved price-version treatment and current
  billable quantity rules.
- Required advance reminders state renewal date, expected amount and
  cancellation route.
- A verified successful charge extends entitlement exactly once.
- Duplicate events, clock differences and client retries cannot create multiple
  renewal periods.
- Manual renewal remains available for non-recurring offerings and invoices.

#### COM-028 — Recover a failed subscription payment

Status: in progress — provider failures drive past-due/grace state and the billing portal provides recovery; retry policy notifications, restricted transition and live recovery evidence remain.

As a billing customer, I need a clear recovery journey after payment failure so
that an expired card does not cause unexplained loss of access.

Acceptance:

- Payment failure moves the subscription through configured past-due, grace,
  restricted and suspended states.
- Retry schedule, grace duration, notifications and restriction behaviour come
  from the offering policy.
- Billing contacts receive safe, actionable notices; ordinary players do not
  receive payment details.
- Successful recovery restores entitlement idempotently without duplicating the
  subscription.
- Permanent failure follows the approved data-preserving expiry policy.
- Administrators can see the provider event and state history without card data.

#### COM-029 — Cancel, refund and dispute a subscription

Status: in progress — cancellation, full/partial immutable refund adjustments and deduplicated refund/dispute operator cases are reconciled idempotently without deleting data; partial-refund access-policy UI and cooling-off approval remain.

As a billing customer or authorised operator, I need cancellations, refunds and
disputes handled consistently so that access and financial records agree.

Acceptance:

- Cancellation distinguishes end-of-term cancellation from an approved
  immediate termination.
- The customer sees effective date, remaining access and refund policy before
  confirming.
- Full and partial refunds create immutable financial adjustments and update
  entitlement according to policy.
- Provider disputes/chargebacks create an operator case and do not silently
  delete customer data.
- Reversal or dispute resolution is idempotent and reconciled.
- Cancellation confirmation and legally required cooling-off handling reflect
  the customer's market and approved terms.

## Increment 3 — League and club purchasing

### Epic C3 — Bulk commercial administration

#### COM-030 — Quote a whole league

As a league administrator, I need a transparent team-count quote so that RooBin
can be funded from existing seasonal registration income.

Acceptance:

- The quote lists included divisions, teams, sport, cycle and exclusions.
- Standard total is calculated from the selected offering's versioned base
  price and billable quantity rules.
- The quote shows quantity, unit, base price, discount, tax and total rather
  than embedding a specific league size or price.
- Trial, volume or annual discounts are shown separately and require authorised
  approval.
- Team-count changes after acceptance follow a documented adjustment policy.

#### COM-031 — Activate a paid league order

As a league administrator, I need one league payment to activate every included
team so that individual captains do not each have to pay.

Acceptance:

- One paid order can grant entitlements to all quoted teams idempotently.
- The league administrator can see activated, failed, duplicate and excluded
  teams.
- Captains receive confirmation but no payment request.
- Later team additions and removals are handled without rebuilding the order.
- Refund and cancellation behaviour is defined for bulk entitlements.

#### COM-032 — Support invoice and bank-transfer settlement

As a league committee, we need an invoice-based option so that payment can
follow the league's normal approval and banking process.

Acceptance:

- An authorised quote can generate a uniquely numbered invoice/order record.
- Pending payment does not silently appear as fully paid access.
- An authorised administrator can reconcile a bank receipt and activate the
  order with a second-person or equivalent audit control.
- Due, paid, overdue, cancelled and refunded states are supported.
- No bank credentials are stored in RooBin.

#### COM-033 — Offer a multi-team club or venue bundle

As a pub or club operating several teams, I need an optional bundle so that
pool and darts adoption can be priced fairly without merging their records.

Acceptance:

- A customer account can own multiple independently permissioned teams.
- Pool and darts seasons remain separate even when commercially bundled.
- Bundle eligibility, price, team limit and cycle coverage are configurable.
- Removing a team from a bundle does not delete or expose its data.
- The offer cannot be enabled until the venue-bundle pricing decision is
  approved.

#### COM-034 — Adjust quantity during a subscription term

As a quantity-based subscriber, I need additions and removals handled according
to the offering so that charges match the covered teams or other billable units.

Acceptance:

- The billable quantity is calculated from an explicit dated subscription
  membership, not a transient UI count.
- Adding quantity can create an immediate or prorated charge according to the
  offering policy.
- Removing quantity can apply immediately, at renewal or with credit according
  to policy.
- The customer previews financial and entitlement impact before confirmation.
- Concurrent changes and provider retries are idempotent.
- Every quantity change retains before/after membership and calculation detail.

#### COM-035 — Cover Team access through a League subscription

As a team in a subscribing league, we need Team capabilities supplied by the
League entitlement so that captains are not asked to buy duplicate access.

Acceptance:

- The offering entitlement matrix identifies which RooBin Team capabilities are
  included by a League subscription.
- Approved league registration activates derived coverage for the correct team
  and period.
- Withdrawal, transfer, league expiry and season rollover update derived
  coverage according to policy.
- The Team UI identifies league-provided access without exposing the league's
  billing details.
- Loss of league coverage falls back to any independently valid Team
  subscription before restricting access.

#### COM-036 — Prevent and resolve overlapping purchases

As a captain, I need protection from paying twice when my league adopts RooBin
or I already hold valid access.

Acceptance:

- Checkout checks current, scheduled and derived entitlements before payment.
- An overlapping purchase is blocked or presents an approved extension, credit
  or upgrade treatment.
- When a League subscription supersedes paid Team access, the configured policy
  can retain, extend, credit or refund the independent subscription.
- No automated credit or refund occurs without an approved offering rule.
- Every resolution is visible to the billing customer and reconciled.

#### COM-037 — Transfer subscription administration safely

Status: in progress — billing ownership is independent of team roles, and nominated recent-auth handover with recipient acceptance, expiry, contact synchronisation and audit is implemented; production notification delivery and the high-risk support recovery drill remain.

As an organisation whose volunteers change, we need subscription administration
transferred without moving ownership of historical financial records.

Acceptance:

- A verified current billing administrator can nominate a replacement.
- Recovery exists when the previous contact is unavailable, with evidence and
  platform-owner approval.
- Transfer does not change provider customer, payer, entitlement or invoice
  history unless separately authorised.
- Both parties receive confirmation where contact remains possible.
- High-risk recovery is audited and protected against support impersonation.

#### COM-038 — Calculate tax and produce compliant adjustments

Status: in progress — catalogue tax behaviour, Stripe automatic tax and immutable adjustment ledger are implemented; VAT/supplier evidence and accountant approval remain.

As the platform owner, I need approved tax treatment applied consistently so
that checkout, invoices, refunds and reporting are correct.

Acceptance:

- Tax determination uses offering tax behaviour, customer evidence and the
  approved payment/tax provider configuration.
- Displayed prices state whether tax is included or added.
- Customer tax identifiers can be collected and validated where required.
- Invoices and receipts show legally required supplier, customer, tax and
  currency information.
- Refunds and corrections produce credit notes or equivalent adjustments rather
  than rewriting issued documents.
- Tax evidence and calculations follow approved retention and access rules.

#### COM-039 — Reconcile subscription state end to end

Status: in progress — reconciliation detects missing financial/entitlement/provider-event states, compares scheduled Stripe subscription state and opens deduplicated operator cases without silent repair; production scheduling and an approved repair exercise remain.

As the platform owner, I need scheduled reconciliation between provider events,
payments, subscriptions and entitlements so that drift is detected before it
affects customers.

Acceptance:

- Reconciliation compares provider customer, subscription, invoice, payment,
  refund and dispute state with RooBin records.
- Missing, duplicated, stale and contradictory states create actionable cases.
- Safe repairs are idempotent; financial or entitlement-impacting repairs need
  authorised confirmation.
- Results are measurable and alert on repeated failure.
- Reconciliation never relies on a client being opened.

## Increment 4 — Native commerce

### Epic C4 — Store-compliant purchasing

#### COM-040 — Validate native purchasing routes

Status: complete — the dated payment architecture records Apple rules, approved StoreKit/web routes, regional/store risks and legal/tax gates before implementation.

As the product owner, I need an approved platform purchasing design so that web,
iOS and future Android sales comply with current store rules.

Acceptance:

- Apple and Google rules are reviewed for team access, league invoices,
  external purchase links and account entitlements.
- Regional differences and effective dates are recorded.
- The approved route identifies which products require native billing.
- Legal/tax review and store-review risks are documented before implementation.

#### COM-041 — Purchase or restore access on iOS

Status: in progress — StoreKit purchase/restore, app-account binding and server JWS verification compile successfully; App Store Connect product and sandbox end-to-end evidence remain.

As an eligible iOS captain, I need a compliant purchase and restore journey so
that paid access follows my team across devices.

Acceptance:

- Store products map to server catalogue products without trusting the client.
- Signed transactions are verified server-side before entitlement activation.
- Pending, cancelled, refunded and restored transactions are handled.
- Restore does not grant access to the wrong team or duplicate an entitlement.
- League-paid members can sign in without being prompted to purchase.

#### COM-042 — Prepare Android billing compatibility

Status: complete — provider-neutral subscriptions, events and entitlements include Google Play identifiers without embedding Apple assumptions; Android delivery remains explicitly optional.

As the delivery team, we need the commercial contract to support future Google
Play billing so that Android does not require a second entitlement model.

Acceptance:

- Provider-neutral payment and entitlement identifiers are used.
- Google purchase tokens can be verified server-side when Android is built.
- No Apple-specific assumption is embedded in team access checks.
- Android implementation remains deferred until an Android delivery increment
  is approved.

## Increment 5 — Scale, support and commercial experiments

### Epic C5 — Sustainable operation

#### COM-054 — Publish the product entitlement matrix

Status: complete — versioned capability definitions drive backend enforcement and status, and the public operating runbook records trial/paid/grace/expired behavior.

As the platform owner, I need every offering mapped to explicit capabilities so
that RooBin Team and RooBin League packaging remains understandable and
enforceable.

Acceptance:

- Capabilities have stable identifiers and user-facing descriptions.
- Each published offering version identifies included, excluded and limited
  capabilities.
- The same matrix drives backend enforcement, pricing comparison and account
  status displays.
- Removing a capability from a future offer does not rewrite existing customer
  rights without the approved migration policy.
- Matrix changes have automated entitlement tests across Team and League roles.

#### COM-055 — Operate customer support cases

Status: in progress — minimal case intake, restricted triage, priorities, ownership and separate customer/internal updates are implemented; mailbox target and escalation owner remain external approvals.

As a customer, I need subscription help tracked to resolution so that payment
and access problems do not disappear in email.

Acceptance:

- Support cases classify billing, entitlement, refund, access and technical
  issues without collecting unnecessary team content.
- Cases have owner, priority, state, customer-visible updates and resolution.
- Support actions link to, but do not alter, audited commercial records.
- Service targets and escalation routes are published internally and reflected
  accurately in customer terms.
- Support staff operate with least privilege and cannot view card data.

#### COM-056 — Publish service status and incident communication

Status: in progress — public component/incident status, restricted audited incident administration and operating guidance are implemented; the production notification channel, owner and live incident exercise remain.

As a paying customer, I need reliable incident information so that I can
distinguish an outage from an account or payment problem.

Acceptance:

- Public status covers web, authentication, data, notifications and payments at
  an appropriate service level.
- Incidents record start, impact, updates, mitigation and resolution.
- Payment incidents do not trigger duplicate checkout or entitlement grants.
- Material incidents notify affected customers through approved channels.
- Post-incident actions are tracked without making unsupported SLA promises.

#### COM-057 — Back up and recover commercial records

Status: in progress — scope, RPO/RTO, safe restore procedure and reconciliation gates are documented; production PITR and first sanitised restore drill remain external actions.

As the platform owner, I need tested recovery for catalogue, subscription and
financial metadata so that a platform failure does not lose customer rights.

Acceptance:

- Backup scope includes catalogue versions, discounts, billing customers,
  subscriptions, entitlements, invoices, audit and reconciliation state.
- Recovery objectives are documented and appropriate to paid operation.
- Restore is tested in a non-production environment using sanitised evidence.
- Provider records can be used for reconciliation but are not treated as a
  substitute for RooBin audit history.
- Recovery cannot grant access or issue money twice.

#### COM-058 — Protect commercial journeys from abuse

Status: in progress — checkout, billing-portal, App Store verification and support limits, honeypot, trial/code constraints, replay protection and audited overrides exist; production false-positive monitoring and tuning remain.

As the platform owner, I need fraud and abuse controls so that discounts,
trials, checkout and support recovery cannot be exploited cheaply.

Acceptance:

- Rate limits cover offer discovery, code redemption, checkout creation,
  payment recovery and support-sensitive actions.
- Trial and code abuse signals are reviewed without making unsupported identity
  inferences.
- Suspicious activity can be challenged or held for review without exposing
  detection rules.
- Legitimate customers have an appeal/support route.
- Abuse controls and overrides are audited and monitored for false positives.

#### COM-059 — Retain and delete commercial data correctly

Status: in progress — per-record retention, anonymisation, observable run contracts and idempotent lifecycle execution are implemented and wired into the scheduled notification worker; production scheduling and processor-deletion evidence remain.

As a customer, I need commercial records retained only as required while valid
financial and entitlement evidence is preserved.

Acceptance:

- Retention is defined for billing contacts, provider references, invoices,
  tax evidence, discounts, subscriptions, audit and support cases.
- Account deletion removes or anonymises non-required personal fields while
  retaining legally required financial records.
- Retained records are access-restricted and no longer used for marketing.
- Processor deletion and export capabilities are documented.
- Retention jobs are observable, idempotent and tested.

#### COM-050 — Monitor capacity and commercial cost thresholds

Status: in progress — monthly usage/cost data and 70/85/95 percent runbook thresholds are implemented; Supabase/Vercel console alerts and first live review remain external actions.

As the operator, I need alerts before platform limits or unexpected charges are
reached so that growth does not interrupt paid teams.

Acceptance:

- Alerts cover Supabase database, storage, egress, MAU and authentication email.
- Vercel usage and spending alerts are configured for the commercial plan.
- Warning and action thresholds have owners and runbooks.
- Cost per active and paid team-season is reviewed monthly.

#### COM-051 — Support commercial corrections safely

Status: complete — least-privilege inspection, audited single and bulk entitlement corrections, mandatory bulk preview/confirmation, idempotency, bounded selection and operator-case evidence are implemented.

As support staff, I need controlled tools for correcting access so that customer
problems can be resolved without direct database editing.

Acceptance:

- Authorised tools can inspect payment and entitlement state with least
  privilege.
- Extensions, revocations, transfers and corrections require a reason and are
  audited.
- Support cannot retrieve payment credentials, unlock codes or private fine
  content unnecessarily.
- High-impact bulk corrections require preview and explicit confirmation.

#### COM-052 — Test a permanent free tier

As the product owner, I need a measured freemium experiment so that acquisition
benefit can be compared with support and infrastructure cost.

Acceptance:

- Free capabilities and limits are explicit and server-enforced.
- Free access completes a useful core journey and does not remove statutory
  data rights.
- Conversion, retention, support demand and resource cost are compared with
  trial-only acquisition.
- No permanent free tier is enabled by default before approval.

#### COM-053 — Evaluate non-targeted sponsorship

As the product owner, I need a privacy-conscious sponsorship experiment so that
league or venue sponsorship can be assessed without behavioural advertising.

Acceptance:

- Sponsorship is clearly labelled and configured by league, club or venue.
- No fine, payment or player-profile data is used for targeting.
- Consent, content approval, reporting and removal processes are defined.
- Programmatic advertising SDKs remain out of scope unless separately approved.

## Recommended delivery path

1. Complete COM-001 through COM-004 and COM-016 through COM-019 before promising
   a formal price, discount or renewal.
2. Complete COM-005 through COM-009 before inviting a whole league into a
   formal pilot; a private technical test may precede the public site.
3. Complete COM-054 through COM-059 for packaging, support, recovery, abuse and
   retention foundations.
4. Build COM-010 through COM-015 for controlled Team/League pilots; invoice or
   reconcile an early pilot manually under controlled administration.
5. Add direct Team checkout and lifecycle through COM-020 through COM-029 plus
   COM-037 through COM-039.
6. Add league quoting, invoicing, quantity adjustment and derived Team access
   through COM-030 through COM-036 when League purchasing opens.
7. Implement native commerce only after COM-040 confirms the current store
   route; use COM-041 for iOS and retain COM-042 for future Android.
8. Keep COM-052 freemium and COM-053 sponsorship as measured experiments rather
   than launch dependencies.
