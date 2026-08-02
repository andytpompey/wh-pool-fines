# RooBin Master Product Backlog

Status: complete proposed scope baseline  
Updated: 2 August 2026

This is the delivery index for the two approved RooBin product tracks:

1. **RooBin Fines Team** — the existing team fines, subs and payment-tracking
   product plus a complete configurable subscription service.
2. **RooBin League** — the multi-sport league-management service, including
   automated scheduling, competitions, communications, league finance, public
   league sites and production operation.

Detailed acceptance criteria live in:

- [`BACKLOG_REGISTER.md`](BACKLOG_REGISTER.md) — generated cross-product view
  for product, platform, status, release, criticality and dependencies
- [`COMMERCIAL_MODEL_BACKLOG.md`](COMMERCIAL_MODEL_BACKLOG.md)
- [`LEAGUE_MANAGEMENT_BACKLOG.md`](LEAGUE_MANAGEMENT_BACKLOG.md)
- [`ios/IOS_BACKLOG.md`](ios/IOS_BACKLOG.md) for the existing native delivery
  programme

Story IDs are stable references and do not imply repository issue numbers or
execution order. Delivery order is defined below.

Run `npm run backlog:build` after changing story titles or delivery metadata.
The generated register is the quickest way to group work by RooBin Fines versus
League Management, delivery surface and lifecycle state.

## Scope totals

| Backlog | Stories | Purpose |
|---|---:|---|
| Commercial (`COM`) | 52 | Catalogue, Team/League subscriptions, payments, entitlements, website, native commerce and operation |
| League (`LM`) | 69 | Full league product, automation, messaging, migration, finance and production operation |
| Combined new product scope | 121 | Excludes the separately maintained iOS application-delivery stories |

The count includes later approved platform capabilities but identifies optional
experiments separately. A story is not complete merely because an adjacent iOS
or web screen exists; its backend, policy, operations and evidence must also be
complete.

## Product packaging boundary

### RooBin Fines Team

- Sold through a platform-owner-maintained offering such as team-season.
- Initial proposed price is GBP 10 per team per season, but price and billing
  model are catalogue data rather than code.
- One authorised payer covers the team; ordinary players do not buy individual
  subscriptions.
- Includes the existing fine, sub, balance, payment, match and team-management
  outcomes selected by the published entitlement matrix.

### RooBin League

- Sold through a separately maintained quantity/organisation offering.
- Base price, quantity unit, interval, trial, discount, renewal and included
  capabilities are maintained by the platform owner.
- Can include RooBin Fines Team access for registered teams through derived
  entitlement, avoiding duplicate captain purchases.
- Provides organisation, registration, divisions, scheduling, results,
  competitions, communications, finance, public site and integration.

## Track A — Complete RooBin Fines Team subscription

### A0 — Commercial definition and administration

Required stories:

- `COM-001` — Define the commercial catalogue
- `COM-002` — Define the paid season boundary
- `COM-003` — Establish the unit-economics dashboard
- `COM-004` — Approve commercial terms and customer ownership
- `COM-016` — Manage subscription offerings
- `COM-017` — Schedule and version base prices
- `COM-018` — Configure offering eligibility and trials
- `COM-019` — Audit and report commercial catalogue activity
- `COM-024` — Create, issue and redeem discount codes
- `COM-038` — Calculate tax and produce compliant adjustments
- `COM-054` — Publish the product entitlement matrix
- `COM-059` — Retain and delete commercial data correctly

Exit gate:

- A platform owner can publish a valid Team offering and base price, issue a
  controlled discount and preview the exact capabilities, tax behaviour and
  customer terms without code or database editing.

### A1 — Public purchasing and support presence

Required stories:

- `COM-005` — Refresh the TroveFinds holding site
- `COM-006` — Establish RooBin public routing on Vercel
- `COM-007` — Publish the RooBin proposition
- `COM-008` — Publish pricing and the founding-league offer
- `COM-009` — Provide the public support and policy hub
- `COM-040` — Validate native purchasing routes
- `COM-055` — Operate customer support cases
- `COM-056` — Publish service status and incident communication

Exit gate:

- A prospective captain can discover RooBin, understand the currently published
  Team offer, access terms/privacy/support and reach the correct compliant
  purchase route.

### A2 — Entitlement and trial foundation

Required stories:

- `COM-010` — Store team-season entitlements
- `COM-011` — Enforce entitlements on the server
- `COM-012` — Grant a controlled founding trial
- `COM-013` — Show trial and paid status to captains
- `COM-014` — Handle expiry without losing team data
- `COM-015` — Capture founding-league feedback and conversion
- `COM-058` — Protect commercial journeys from abuse

Exit gate:

- Trial, paid, grace and expired access produce consistent outcomes on web and
  native clients and cannot be self-granted by a modified client.

### A3 — Team checkout and subscription lifecycle

Required stories:

- `COM-020` — Purchase GBP 10 team-season access
- `COM-021` — Process payment events idempotently
- `COM-022` — Issue receipts and reconcile revenue
- `COM-023` — Renew or purchase the next season
- `COM-025` — Manage the billing customer and payer
- `COM-026` — Manage payment methods securely
- `COM-027` — Renew a subscription automatically
- `COM-028` — Recover a failed subscription payment
- `COM-029` — Cancel, refund and dispute a subscription
- `COM-037` — Transfer subscription administration safely
- `COM-039` — Reconcile subscription state end to end
- `COM-050` — Monitor capacity and commercial cost thresholds
- `COM-051` — Support commercial corrections safely
- `COM-057` — Back up and recover commercial records

Exit gate:

- A captain can buy, renew, update payment method, recover failure, cancel and
  receive the correct documents while RooBin independently reconciles payment,
  subscription and entitlement state.

### A4 — Native Team purchase

Required stories:

- `COM-041` — Purchase or restore access on iOS

Future platform compatibility:

- `COM-042` — Prepare Android billing compatibility

Exit gate:

- The approved store route works without granting access from unverified client
  receipts and league-paid members are never incorrectly prompted to buy.

## Track B — Complete RooBin League commercial subscription

Required stories:

- `COM-030` — Quote a whole league
- `COM-031` — Activate a paid league order
- `COM-032` — Support invoice and bank-transfer settlement
- `COM-033` — Offer a multi-team club or venue bundle
- `COM-034` — Adjust quantity during a subscription term
- `COM-035` — Cover Team access through a League subscription
- `COM-036` — Prevent and resolve overlapping purchases

These depend on Track A's catalogue, customer, discount, tax, payment,
entitlement, lifecycle, reconciliation, support and recovery stories. League
commercial scope is not complete if a quantity change or derived Team access
requires manual database editing.

Exit gate:

- A platform owner can maintain a League offering and discount; an authorised
  organisation can quote, buy and administer it; quantity changes follow the
  published rule; and covered teams receive the correct non-duplicated access.

## Track C — Full League Management product

### C0 — Organisation, registration and governance

Required stories:

- `LM-001` — Model a multi-sport league organisation
- `LM-002` — Establish league roles and permissions
- `LM-003` — Register subscribed teams into a season
- `LM-004` — Configure venues and playing capacity
- `LM-005` — Define versioned sport rulesets
- `LM-006` — Configure season registration
- `LM-007` — Register or re-register a team
- `LM-008` — Allocate teams to divisions
- `LM-009` — Register and govern players

### C1 — Automated league scheduling

Required stories:

- `LM-010` — Configure the season playing calendar
- `LM-011` — Calculate schedule feasibility
- `LM-012` — Generate round-robin pairings
- `LM-013` — Balance home and away fixtures
- `LM-014` — Resolve scheduling conflicts
- `LM-015` — Preview, version and publish a schedule
- `LM-016` — Notify captains and venues of fixtures

### C2 — Match formats, people, results and standings

Required stories:

- `LM-020` — Define a configurable match pattern
- `LM-021` — Provide initial pool match templates
- `LM-022` — Validate match line-ups
- `LM-023` — Submit and confirm a result
- `LM-024` — Configure standings and tie-break rules
- `LM-025` — Add a validated darts rules adapter
- `LM-026` — Manage player eligibility and transfers
- `LM-027` — Resolve result disputes and protests
- `LM-028` — Roll a season forward
- `LM-029` — Publish statistics, awards and records

### C3 — Cups and tournaments

Required stories:

- `LM-030` — Create a knockout competition
- `LM-031` — Perform an auditable random draw
- `LM-032` — Resolve dependent knockout fixtures automatically
- `LM-033` — Select eligible neutral venues
- `LM-034` — Optimise neutral venue travel fairly
- `LM-035` — Notify and confirm tournament venue selection
- `LM-036` — Handle byes, withdrawals and walkovers

### C4 — Combined calendar and change management

Required stories:

- `LM-040` — Generate a combined league and cup calendar
- `LM-041` — Re-optimise after a material change
- `LM-042` — Support postponement and rearrangement
- `LM-043` — Simulate alternative schedules

### C5 — Communication, moderation and public experience

Required stories:

- `LM-050` — Send league and division announcements
- `LM-051` — Provide fixture and match threads
- `LM-052` — Publish league fixtures, tables and brackets
- `LM-053` — Store conversations and durable messages
- `LM-054` — Deliver realtime messages and unread state
- `LM-055` — Configure messaging notifications
- `LM-056` — Report a message or user
- `LM-057` — Block another user
- `LM-058` — Moderate user-generated content
- `LM-059` — Publish and enforce messaging standards
- `LM-065` — Enable direct player messaging safely

Optional after text messaging is operational:

- `LM-066` — Add moderated message attachments

### C6 — Migration, shadow operation and cutover

Required stories:

- `LM-060` — Import a league from RackEm
- `LM-061` — Run a shadow season reconciliation
- `LM-062` — Cut a league over to RooBin authority
- `LM-063` — Govern ruleset and solver versions
- `LM-064` — Monitor league automation quality

### C7 — League finance, documents and branding

Required stories:

- `LM-070` — Configure league charges
- `LM-071` — Collect league registrations and entry fees
- `LM-072` — Invoice and reconcile offline league payments
- `LM-073` — Refund and adjust league charges
- `LM-074` — Report league finances
- `LM-075` — Manage league documents and policies
- `LM-076` — Manage league branding and sponsors

### C8 — Integration and production operation

Required stories:

- `LM-080` — Provide a versioned League API
- `LM-081` — Publish outbound webhooks
- `LM-082` — Export league data
- `LM-083` — Back up and recover League data
- `LM-084` — Operate platform administration and support
- `LM-085` — Enforce privacy and retention across League data
- `LM-086` — Meet production security and reliability gates
- `LM-087` — Audit authoritative league actions

## Explicitly optional commercial experiments

These stories remain in the commercial backlog but do not block the complete
paid Team or League products:

- `COM-052` — Test a permanent free tier
- `COM-053` — Evaluate non-targeted sponsorship
- `LM-066` — Add moderated message attachments

Advertising is not part of the approved core model. Android implementation is
not part of the current iOS release, although `COM-042` preserves compatibility.

## Cross-track critical dependencies

| Outcome | Required predecessors |
|---|---|
| Publish Team price | Catalogue, price version, entitlement matrix, terms and tax treatment |
| Take first payment | Billing customer, checkout, provider events, receipts, entitlement and support route |
| Enforce paid Team access | Server entitlement, expiry policy and data-rights fallback |
| Sell League | Complete Team commerce foundation plus League quote, quantity and organisation billing |
| Include Team with League | `COM-035` and `COM-036` plus approved league registration from `LM-003`/`LM-007` |
| Publish fixtures | League foundation, feasibility, generation, conflict resolution, preview/versioning and notifications |
| Advance a cup automatically | Final results, auditable draw, dependency resolution and eligible venue selection |
| Enable any chat | Durable messages, reporting, blocking, moderation, standards and support operation |
| Enable direct messages | All shared-chat safeguards plus `LM-065` |
| Replace RackEm | Import, complete shadow season, production gates, exports, support and approved cutover |
| Support darts | Shared League foundation plus a named-league validation and `LM-025` |

## Delivery sequence

### Release 1 — Paid RooBin Fines Team

1. A0 commercial administration.
2. A1 public/support presence.
3. A2 entitlements and controlled trial.
4. A3 web checkout and complete subscription lifecycle.
5. A4 native purchase only through the approved store route.

### Release 2 — Pool League Lite

1. B League commercial subscription foundation.
2. C0 organisation, registration and governance.
3. C1 automated league scheduling.
4. C2 pool match operation and standings, excluding darts until validated.
5. C5 public fixtures and operational announcements.

### Release 3 — Complete Pool League

1. C3 cups and neutral venue automation.
2. C4 combined calendar and rescheduling.
3. C5 complete messaging/moderation.
4. C7 league finance, documents and branding.
5. C8 integration and production operation.

### Release 4 — Replacement and multi-sport

1. C6 RackEm import and shadow season.
2. Approved cutover after reconciliation.
3. Validate and implement darts through `LM-025`.
4. Add further sport templates only through the governed ruleset model.

## Definition of done for every required story

A story is complete only when all applicable items are satisfied:

- Product behaviour and exception policy are approved.
- Schema/API migrations are versioned, reversible where practicable and tested
  from a clean environment.
- Server-side authorisation, tenant isolation and rate limits are verified.
- Payment, scheduling, result and notification mutations are idempotent where
  retries are possible.
- Web compatibility and native contract impact are tested.
- Loading, empty, offline/retry, forbidden and failure states are implemented.
- Accessibility and privacy requirements are verified.
- Audit, monitoring, support diagnostics and customer-safe errors exist.
- Data retention, export, deletion and recovery consequences are covered.
- Automated tests and proportionate staging evidence pass.
- Customer/support/operator documentation is current.
- No production rollout is claimed until deployment and smoke tests are
  explicitly verified.

## Programme completion gates

### RooBin Fines Team subscription is complete when

- a platform owner can maintain an offering, base price and discount;
- a captain can purchase and manage access through the approved channel;
- payment, entitlement, invoice and renewal state reconcile automatically;
- failure, cancellation, refund, transfer and expiry preserve correct rights;
- web/iOS show one authoritative subscription state; and
- support, security, backup, tax, privacy and incident processes are operating.

### RooBin League is complete when

- a league can register teams/players, allocate divisions and configure rules;
- the solver can explain feasibility and publish fair league/cup schedules;
- scorecards, disputes, standings and knockout dependencies are authoritative;
- neutral venues and notifications follow the approved automated policy;
- league/division/team/direct messaging has full UGC safeguards;
- league fees, documents, branding, public pages, APIs and exports work;
- a full shadow season reconciles and an approved cutover succeeds; and
- production security, recovery, monitoring, audit and support gates pass.
