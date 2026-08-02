# RooBin League Management Backlog

Status: proposed product backlog  
Updated: 2 August 2026  
Story IDs are stable references; they do not imply repository issue numbers.

## Product direction

RooBin has two connected product tracks:

1. **RooBin Team** — the existing fines, subs and team-finance product, released
   at GBP 10 per team per season.
2. **RooBin League** — an automation-first, multi-sport league-management
   product intended to replace a separate league platform and support an annual
   per-team league subscription.

RooBin League should minimise repetitive committee administration while always
allowing an authorised human to preview, explain and override a generated plan.
An override creates a new auditable schedule version; it never silently rewrites
published history.

## Scheduling vocabulary

- A **season** is the complete competition window between its start and end
  dates.
- A **playing week** is an occurrence generated from the season cadence, such
  as each Thursday night.
- A **round** is the set of fixtures required for every eligible team to play
  once in that stage, subject to a bye where the team count is odd.
- A **match pattern** defines the constituent games/frames/legs in one team
  fixture, for example 12 singles or 10 singles plus 2 doubles.
- A **venue allocation** assigns a fixture to a venue and playing slot.

The scheduler calculates the required playing weeks and rounds within a season;
it does not describe these as additional seasons.

## Scheduling principles

### Hard constraints

- A team cannot play two fixtures in the same unavailable slot.
- A venue cannot host conflicting fixtures beyond its configured capacity.
- Published blackout dates and explicit unavailability are respected.
- League home fixtures use the designated home venue unless an authorised
  exception is recorded.
- A neutral cup venue cannot be either participant's home venue.
- Where the league requires it, a neutral tournament venue must belong to a
  team that remains active in that tournament.
- Dependent knockout participants cannot be resolved until predecessor results
  are final.
- Required competition rounds must fit between the approved start and end dates
  or the plan is reported as infeasible.

### Optimisation objectives

- Balance home and away allocations as evenly as the format permits.
- Minimise the largest participant journey to a neutral venue, then minimise
  combined travel as a secondary objective.
- Minimise consecutive home, consecutive away and repeated-bye sequences.
- Preserve buffer dates and avoid unnecessary changes to published fixtures.
- Prefer venues and slots that have acknowledged availability.

Hard constraints are never relaxed silently to improve an optimisation score.

## Recognised formats and local configuration

RooBin should provide reviewed starting templates, not claim that one template
is mandatory for every local league. The English Pool Association explicitly
allows local leagues to select their own rules. Recognised governing-body and
league patterns are therefore versioned references that a league may copy and
adapt.

Initial examples include:

- Pool single round robin with one home/away allocation per pairing.
- Pool double round robin with reversed venue allocation.
- Pool 12-frame match using 12 singles.
- Pool mixed 12-frame match using 10 singles and 2 doubles.
- Knockout Cup and Plate competition with configurable byes and seeding.
- Round-robin groups followed by knockout qualification.
- Darts singles, pairs and team patterns expressed as legs/sets, introduced only
  after validation with a named darts league.

## Working rules

- Sport-specific behaviour is supplied through versioned ruleset and match-
  pattern definitions rather than client conditionals.
- Random draws record their inputs, exclusions, algorithm version and random
  seed so they can be independently reproduced.
- Travel comparisons use configured route/travel-time data where available;
  straight-line distance is an explicitly labelled fallback.
- Published schedule changes notify affected captains and venues.
- A notification is not proof of acceptance; acknowledgement is recorded
  separately where the league requires it.
- Imported RackEm data retains source identifiers and provenance.
- RooBin is not authoritative for a competition until an approved cutover has
  completed.

## Increment 0 — League foundation

### Epic L0 — Organisations, sports and authority

#### LM-001 — Model a multi-sport league organisation

As a league administrator, I need one organisation to operate one or more sports
without mixing their competition records.

Acceptance:

- Organisation, sport, league, season, division and competition are separate,
  stable entities.
- Pool and darts teams can share an organisation or venue while retaining
  independent membership, rules and results.
- Every competition identifies its authoritative sport ruleset and timezone.
- Organisation deletion, archive and retention behaviour are explicit.
- Cross-organisation access is denied and tested server-side.

#### LM-002 — Establish league roles and permissions

As a committee, we need delegated roles so that work can be distributed without
giving every volunteer unrestricted access.

Acceptance:

- Roles include league administrator, committee member, divisional
  representative, venue contact, captain, vice-captain and player.
- Permissions distinguish configuration, scheduling, publishing, result
  approval, finance, messaging and moderation.
- A user can hold different roles in different organisations or divisions.
- Privileged changes are server-authorised and audited.
- No league role reveals team unlock codes or unrelated private fine data.

#### LM-003 — Register subscribed teams into a season

As a league administrator, I need an approved list of participating teams so
that divisions and schedules use the correct commercial and operational scope.

Acceptance:

- A registration identifies team, sport, season, captain, venue and commercial
  state.
- Pending, approved, withdrawn and rejected registrations are supported.
- Duplicate registrations and conflicting sport/season assignments are
  prevented.
- The subscribed-team count is available to commercial quoting without making
  payment status the source of scheduling truth.
- Late additions and withdrawals show their scheduling impact before approval.

#### LM-004 — Configure venues and playing capacity

As a venue contact, I need to describe when and how many matches we can host so
that generated schedules are feasible.

Acceptance:

- A venue records address, verified coordinates, timezone, contact, sports,
  table/board capacity and accessibility notes.
- Recurring availability, one-off blackouts and exceptional openings are
  supported.
- Multiple teams may designate the same venue.
- Venue capacity can vary by date or playing slot.
- Address and coordinate changes create an audit record and trigger impact
  analysis rather than silently changing published travel calculations.

#### LM-005 — Define versioned sport rulesets

As a league, we need a recognised ruleset starting point that can be adapted to
local practice without changing historic results.

Acceptance:

- A ruleset has sport, source/reference, version, effective dates and local
  amendments.
- A season pins its ruleset version.
- A league can clone an approved template and record deviations.
- Historic fixtures remain attached to the version under which they were
  played.
- Rule documents can be published without implying governing-body endorsement.

#### LM-006 — Configure season registration

As a league administrator, I need to configure team and player registration so
that applications collect the right information and follow league deadlines.

Acceptance:

- Configuration covers opening/closing dates, re-registration, team limits,
  roster limits, required contacts, venue requirements and approval workflow.
- Required declarations, terms and privacy notices are versioned.
- Existing teams can be invited to re-register without duplicating identity or
  history.
- Late-registration behaviour and authorised exceptions are explicit.
- A preview shows the captain-facing form before publication.

#### LM-007 — Register or re-register a team

As a captain, I need to submit my team for a season so that the league can
approve our entry and include us in planning.

Acceptance:

- The captain selects or creates the team, confirms sport, venue and contacts,
  and supplies the required declarations.
- Existing roster and venue data can be reviewed rather than blindly copied.
- Draft, submitted, changes-requested, approved, rejected and withdrawn states
  are supported.
- Duplicate and conflicting applications are prevented.
- Submission provides a receipt/reference and notifies the appropriate league
  role.

#### LM-008 — Allocate teams to divisions

As a league committee, we need to place approved teams into divisions so that
schedule generation uses the agreed competitive structure.

Acceptance:

- Allocation supports manual placement and recommendations based on prior
  standings, promotion/relegation rules and target division sizes.
- New, returning, merged and withdrawn teams are clearly identified.
- The committee can preview movement and division-size consequences.
- Publishing freezes the allocation used by schedule generation.
- Later movement requires impact analysis, reason and schedule versioning.

#### LM-009 — Register and govern players

As a league, we need one controlled player registration record so that roster,
eligibility, transfers and results refer to the correct person.

Acceptance:

- A player can hold memberships across authorised sports, teams and seasons
  without duplicate identity records.
- League-required attributes and verification states are configurable and
  privacy-minimised.
- Captain-created and self-claimed registrations have safe linking/recovery.
- Duplicate detection never exposes another player's private contact details.
- Registration, suspension, transfer and release history is auditable.

## Increment 1 — Smart league scheduling

### Epic L1 — Calendar feasibility and round-robin generation

#### LM-010 — Configure the season playing calendar

As a league administrator, I need to supply the competition window and cadence
so that RooBin can derive every available playing date.

Acceptance:

- Inputs include start date, end date, weekday, recurrence interval, local start
  time, timezone, excluded dates and reserved dates.
- Weekly Thursday-night recurrence is supported.
- Bank holidays, finals nights, breaks and committee blackout dates can be
  included or excluded explicitly.
- The preview lists all derived playing weeks before scheduling.
- Calendar changes show their effect on existing rounds and competitions.

#### LM-011 — Calculate schedule feasibility

As a committee, we need to know whether the requested competitions fit before
fixtures are published.

Acceptance:

- For a single round robin, the engine calculates `n - 1` rounds for an even
  number of teams and `n` rounds with one bye per round for an odd number.
- A double round robin calculates the corresponding reversed second cycle.
- Required cup rounds, reserved dates and configurable buffer weeks are included
  in capacity calculations.
- Venue capacity and unavailable-team constraints contribute to feasibility.
- An infeasible plan identifies the blocking constraints and quantifies the
  shortage.
- Suggested remedies include extending the end date, changing cadence, reducing
  buffers, using parallel slots or changing format; none apply automatically.

#### LM-012 — Generate round-robin pairings

As a league administrator, I need complete and unbiased pairings so that every
team plays the required opponents exactly as configured.

Acceptance:

- Single and double round robin formats are supported.
- Every required pairing occurs exactly once per cycle.
- Odd team counts generate balanced byes.
- The pairing algorithm and version are recorded.
- Regenerating with unchanged inputs is deterministic unless an authorised new
  draw is explicitly requested.
- Automated tests cover even, odd, minimum and configured maximum division
  sizes.

#### LM-013 — Balance home and away fixtures

As a captain, I need a fair home/away schedule so that travel and venue benefit
are distributed evenly.

Acceptance:

- Each fixture has an explicit home team, away team and designated venue.
- Home/away totals are as balanced as mathematically possible.
- Double round robin reverses the first-cycle allocation by default.
- The optimiser limits consecutive home or away runs using a configurable
  threshold.
- Shared-venue and venue-capacity conflicts are resolved or reported.
- Fairness scores and unavoidable exceptions are visible before publication.

#### LM-014 — Resolve scheduling conflicts

As a scheduler, I need conflicts explained and ranked so that I can make the
smallest informed change.

Acceptance:

- Conflicts identify affected teams, venues, dates and violated constraints.
- Hard constraints are distinguished from preference penalties.
- The engine proposes ranked alternatives with an explanation of trade-offs.
- Administrators can lock fixtures that must not move.
- Manual resolution is revalidated against the complete schedule.
- No conflicting schedule can be published without an explicit authorised
  exception and visible warning.

#### LM-015 — Preview, version and publish a schedule

As a league administrator, I need to approve the generated schedule before
captains treat it as official.

Acceptance:

- Draft preview includes rounds, fixtures, home/away totals, byes, venues,
  conflicts, fairness measures and unused dates.
- Administrators can lock, move or swap fixtures and rerun remaining placement.
- Publishing creates an immutable schedule version and records its approver.
- Later changes create a new version with a human-readable change set.
- Captains and venue contacts see only published fixtures as authoritative.

#### LM-016 — Notify captains and venues of fixtures

As a captain or venue contact, I need timely fixture notifications so that I can
prepare and flag problems early.

Acceptance:

- Publication and material changes can notify captains, vice-captains and venue
  contacts through configured in-app, email and push channels.
- Notifications identify competition, date, time, teams, venue and action
  required.
- Venue contacts can acknowledge, decline or query an allocation.
- A decline reopens scheduling as an exception; it does not silently move a
  fixture.
- Delivery and acknowledgement state are visible to authorised league roles.
- Notification retries are idempotent and do not create message storms.

## Increment 2 — Configurable match formats and standings

### Epic L2 — Sport-aware match operation

#### LM-020 — Define a configurable match pattern

As a league administrator, I need to define the games inside a fixture so that
local league formats are supported without code changes.

Acceptance:

- A match pattern contains ordered stages such as singles, doubles, pairs, team
  games, legs, sets or frames.
- Each stage defines participant count, repeat-player rules, scoring, home/away
  order and tie behaviour.
- Total available match points and possible final scores are validated.
- Patterns are versioned and pinned to a competition.
- Changing a pattern cannot reinterpret completed fixtures.

#### LM-021 — Provide initial pool match templates

As a pool league, we need recognised starting patterns so that setup does not
begin with a blank form.

Acceptance:

- Templates include 12 singles and mixed 10 singles plus 2 doubles.
- Template descriptions distinguish a team fixture's constituent frames from
  the season's round-robin scheduling format.
- Player reuse, ordering, substitute and eligibility settings are explicit.
- A league can clone and amend a template before the season begins.
- The source and review date of each recognised template are recorded.

#### LM-022 — Validate match line-ups

As a captain, I need the scorecard to validate our selected line-up so that an
ineligible or duplicated player is caught before play.

Acceptance:

- Validation uses the pinned match pattern and competition eligibility rules.
- Singles, doubles/pairs and substitute constraints are supported.
- Both teams can complete their permitted part of the line-up without viewing
  hidden opponent selections where the format requires secrecy.
- Late registration and exceptional-player decisions are authorised and
  audited.
- A rules warning does not become an automatic disqualification unless the
  competition policy defines it.

#### LM-023 — Submit and confirm a result

As captains, we need a reliable scorecard and confirmation process so that
standings update from an agreed result.

Acceptance:

- The scorecard is generated from the competition's match pattern.
- Each constituent result and aggregate score are validated.
- One captain submits and the opposing captain can confirm or dispute.
- Agreed results become final and update dependent calculations atomically.
- Corrections and walkovers require an authorised, reasoned action and audit.
- Duplicate or retried submissions cannot double-apply standings or advance a
  knockout participant twice.

#### LM-024 — Configure standings and tie-break rules

As a league administrator, I need configurable standings rules so that RooBin
matches the league constitution.

Acceptance:

- Rules cover win/draw/loss points, frame/leg difference, head-to-head, bonus
  points, penalties and ordered tie-breaks.
- A preview calculates example outcomes before the season starts.
- The ruleset version is pinned to the division or competition.
- Penalties record amount, reason, authority and effective result.
- Recalculation is deterministic and produces an audit comparison.

#### LM-025 — Add a validated darts rules adapter

As a darts league, we need darts-specific patterns and scoring without changing
the shared organisation and scheduling system.

Acceptance:

- Work begins only after journeys and real formats are validated with a named
  darts league.
- Legs, sets, singles, pairs and team stages can be represented.
- Initial templates cite their source and review date and remain editable local
  starting points.
- Darts standings and tie-breaks use the shared rules contract.
- Pool clients and historic pool competitions are unaffected.

#### LM-026 — Manage player eligibility and transfers

As a league administrator, I need eligibility and transfer rules enforced so
that scorecards cannot use an unauthorised player unnoticed.

Acceptance:

- Rules can cover registration deadline, division restrictions, cup tying,
  maximum appearances, transfer windows, suspension and guest players.
- A transfer has source team, destination team, effective date, approvals and
  retained history.
- Eligibility is evaluated for the fixture date and pinned competition rules.
- Captains can see actionable eligibility status without unrelated private
  disciplinary detail.
- Authorised exceptions record reason, authority and affected fixtures.

#### LM-027 — Resolve result disputes and protests

As a divisional representative, I need a controlled dispute workflow so that a
contested result does not update official standings prematurely.

Acceptance:

- A captain can dispute within the configured deadline and provide structured
  reason/evidence.
- Disputed results are visibly non-final and block dependent knockout progress.
- Assigned officials can request information, record a decision and apply an
  approved correction or sanction.
- Parties receive the decision and any appeal route.
- Evidence access, retention and audit follow the approved policy.

#### LM-028 — Roll a season forward

As a league administrator, I need a new season created from approved prior data
so that annual setup does not require rebuilding the organisation.

Acceptance:

- The workflow can copy selected rules, formats, venues, roles and registration
  settings while creating new versioned competition records.
- Prior standings can seed promotion/relegation recommendations.
- Teams and players must re-register or be explicitly carried according to the
  approved policy.
- Historic schedules, results and commercial records remain unchanged.
- The new season remains draft until registration and allocation are approved.

#### LM-029 — Publish statistics, awards and records

As a league, we need trustworthy season statistics so that achievements can be
recognised without manual spreadsheets.

Acceptance:

- Statistics derive only from final authoritative scorecards.
- Supported measures are defined by sport and match pattern rather than assumed
  globally.
- Corrections recalculate affected statistics deterministically.
- Public/private visibility and minimum-participation rules are configurable.
- Awards are approved records and do not silently change when display rules are
  edited later.

## Increment 3 — Automated cups and tournaments

### Epic L3 — Draws, dependencies and neutral venues

#### LM-030 — Create a knockout competition

As a league administrator, I need RooBin to derive the bracket from eligible
entries so that cup setup is quick and complete.

Acceptance:

- Straight knockout, Cup/Plate and configurable group-to-knockout structures
  are supported incrementally.
- The engine calculates bracket size, rounds and required byes.
- Eligibility and entry cut-off are explicit.
- Cup dates can be reserved within the league-season calendar.
- A preview shows every dependency and provisional playing week before draw.

#### LM-031 — Perform an auditable random draw

As participating teams, we need confidence that a random draw was fair and not
silently manipulated.

Acceptance:

- The draw records entrants, exclusions, seed groups, bye policy, algorithm
  version, random seed, actor and timestamp.
- The result can be independently reproduced from its audit record.
- Seeded, fully random and constrained-random modes are distinguished.
- Same-team, same-venue or same-division avoidance is applied only when an
  approved draw rule requires it.
- Redrawing requires a reason, retains the previous draw and notifies affected
  teams.

#### LM-032 — Resolve dependent knockout fixtures automatically

As a cup participant, I need my next opponent and fixture confirmed as soon as
the required predecessor results are final.

Acceptance:

- Bracket fixtures reference winner/loser dependencies rather than placeholder
  team names.
- When all dependencies become final, the next fixture resolves exactly once.
- The configured next-round date/slot is used where already reserved.
- Venue selection runs after participants are known when neutrality depends on
  their identities.
- Captains and the selected venue are notified promptly and idempotently.
- A disputed predecessor result blocks advancement and displays the reason.

#### LM-033 — Select eligible neutral venues

As a league, we need neutral tournament fixtures hosted only at acceptable
venues.

Acceptance:

- Candidate venues exclude both participants' home venues.
- Where configured, a candidate must be the venue of a team still active in the
  tournament at the selection point.
- Availability, sport capability, capacity and blackout constraints apply.
- Candidate eligibility is evaluated from a time-stamped tournament state.
- If no venue satisfies every hard constraint, RooBin stops and presents the
  exact reason plus authorised exception options.

#### LM-034 — Optimise neutral venue travel fairly

As participating teams, we need the closest fair eligible venue so that neither
side carries an unreasonable travel burden.

Acceptance:

- Travel is calculated from each team's designated origin to every eligible
  venue using a configured route/travel-time provider where available.
- The primary ranking minimises the larger of the two journeys.
- The secondary ranking minimises combined journey time/distance.
- Deterministic tie-breaks and the selected calculation mode are recorded.
- Straight-line fallback is labelled and cannot be presented as route time.
- Administrators can view ranked candidates and reasons for exclusion.

#### LM-035 — Notify and confirm tournament venue selection

As a selected venue contact, I need to accept or decline promptly so that the
cup fixture does not remain uncertain.

Acceptance:

- The venue receives teams, competition, round, date, time, capacity need and
  response deadline.
- Captains receive provisional or confirmed status as appropriate.
- Acceptance confirms the allocation and notifies participants.
- Decline selects the next ranked eligible venue or opens an exception according
  to league policy.
- A venue cannot receive conflicting provisional holds beyond its capacity.
- Response history and automated fallback decisions are audited.

#### LM-036 — Handle byes, withdrawals and walkovers

As a tournament administrator, I need exceptional outcomes to advance the
correct dependency without corrupting the bracket.

Acceptance:

- Byes advance automatically under the approved draw policy.
- Pre-start and post-start withdrawal rules can differ.
- Walkovers require an authorised result and reason.
- Advancing a participant resolves downstream dependencies exactly once.
- A reversal identifies every affected downstream fixture and requires an
  explicit recovery plan before application.

## Increment 4 — Combined league and cup optimisation

### Epic L4 — Whole-season planning and change management

#### LM-040 — Generate a combined league and cup calendar

As a committee, we need one schedule covering division and knockout activity so
that competitions do not compete for the same teams, venues or nights.

Acceptance:

- League rounds, cup rounds, plate rounds, breaks, finals and buffers share one
  planning horizon.
- Cup-only weeks, parallel cup/league weeks and exempt teams are configurable.
- Unresolved knockout participants reserve capacity without inventing team
  identity.
- The feasibility report shows required and spare playing weeks.
- Publishing creates one coherent schedule version with competition-specific
  views.

#### LM-041 — Re-optimise after a material change

As a scheduler, I need RooBin to repair the smallest possible part of a schedule
after a withdrawal, venue loss or postponement.

Acceptance:

- Published fixtures and administrator locks carry a high change penalty.
- The engine scopes affected fixtures and proposes a minimal-change repair.
- Every proposed move identifies newly affected teams and venues.
- The original schedule remains available for comparison and rollback planning.
- No repair publishes automatically unless an explicitly approved policy covers
  that precise change class.

#### LM-042 — Support postponement and rearrangement

As captains, we need a controlled rearrangement process so that both teams, the
venue and league agree the replacement fixture.

Acceptance:

- A request records initiator, reason, affected fixture and proposed dates.
- Candidate dates respect team, venue and competition constraints.
- Required approvals and notice periods are configurable.
- Acceptance updates the schedule version and notifies all affected parties.
- Outstanding requests and deadline breaches are visible to divisional roles.

#### LM-043 — Simulate alternative schedules

As a league administrator, I need to compare viable plans so that automation
supports a policy decision rather than hiding it.

Acceptance:

- Alternatives can vary start/end, cadence, cup placement, buffers and permitted
  parallelism without mutating the approved configuration.
- Comparisons include feasibility, number of changes, travel fairness,
  home/away balance, consecutive patterns and spare dates.
- Each simulation records its complete inputs and solver version.
- An alternative can be promoted to draft but never directly to published.

## Increment 5 — Communication and public league experience

### Epic L5 — Timely information for leagues, divisions and teams

#### LM-050 — Send league and division announcements

As a league role, I need scoped announcements so that fixture and competition
information reaches the correct participants quickly.

Acceptance:

- Audience can be league, division, competition, selected teams or venues.
- Posting permission follows the league role matrix.
- Scheduled and urgent announcements are supported.
- Delivery, read and required acknowledgement states are distinguished.
- Reporting, moderation, retention and notification preferences follow the
  approved messaging policy.

#### LM-051 — Provide fixture and match threads

As participants, we need communication attached to the relevant fixture so that
arrangements are not lost in a general chat.

Acceptance:

- Published fixtures can have a thread scoped to authorised team and league
  members.
- System events such as venue change, postponement and result finalisation are
  immutable thread entries.
- User messages support reporting and blocking requirements.
- Thread membership updates safely after roster or role changes.
- Direct player-to-player messaging remains a separately approved phase.

#### LM-052 — Publish league fixtures, tables and brackets

As a follower, I need a public league site so that official competition
information is accessible without joining a team.

Acceptance:

- Public pages show approved fixtures, results, tables, brackets, venues,
  announcements, rules and sponsors according to publication policy.
- Drafts, disputes, private contact details and internal scheduling notes are
  excluded.
- Changes carry last-updated state and stable public URLs.
- Pages are responsive, accessible and indexable only where approved.
- Each public result traces to an authoritative final record.

#### LM-053 — Store conversations and durable messages

As a participant, I need messages retained in the correct conversation so that
chat history is available across devices and can be moderated when necessary.

Acceptance:

- Conversation types include team, fixture, division, competition, league and
  direct conversation where enabled.
- Membership is derived from authoritative roles/registrations and has dated
  join/leave history.
- Messages are stored durably; realtime delivery is not the sole message store.
- Sending, editing and deletion policies are explicit and server-enforced.
- Cross-conversation and removed-member access is denied and tested.

#### LM-054 — Deliver realtime messages and unread state

As a member, I need timely messages and accurate unread indicators so that I do
not miss operational updates.

Acceptance:

- New messages arrive through reconnect-safe realtime subscriptions.
- Pagination and reconnect do not duplicate or omit durable messages.
- Read position is tracked per user/conversation without a receipt storm.
- Offline and background clients recover from the durable history.
- Realtime connection and message volumes are monitored against platform
  quotas.

#### LM-055 — Configure messaging notifications

As a user, I need channel-specific notification preferences so that urgent
league changes reach me without every chat becoming disruptive.

Acceptance:

- Preferences distinguish direct, team, fixture, division, league announcement
  and urgent operational events.
- In-app, email and push delivery can be configured according to available
  channels and mandatory-service policy.
- Quiet hours and mute duration respect local timezone.
- Security and legally required notices cannot be disabled through chat
  preferences.
- Notification events are idempotent and link to an authorised destination.

#### LM-056 — Report a message or user

As a user, I need to report objectionable content or behaviour from within the
conversation so that RooBin can investigate and meet platform-safety duties.

Acceptance:

- Message and user reports are available in every user-generated-content
  surface.
- Report categories, optional detail and immediate-safety guidance are clear.
- Evidence is preserved according to policy even if the sender deletes the
  visible message.
- The reporter receives a reference and can see an appropriate status.
- Reports do not notify the reported user automatically or expose reporter
  identity unnecessarily.

#### LM-057 — Block another user

As a user, I need to block direct interaction with another user so that I can
protect myself without leaving my team or league.

Acceptance:

- Blocking prevents new direct messages, mentions and other configured direct
  interactions.
- Necessary system, fixture and league announcements remain available without
  revealing avoidable personal interaction.
- Block state is private and enforced server-side.
- Unblocking does not restore deleted history or resend missed direct messages.
- Direct messaging cannot launch without block functionality.

#### LM-058 — Moderate user-generated content

As an authorised moderator, I need a review queue and proportionate actions so
that reports receive timely and consistent handling.

Acceptance:

- The queue supports assignment, priority, evidence view, decision, internal
  notes and customer-safe outcome.
- Actions can include no action, content removal, warning, channel restriction,
  temporary suspension and account escalation.
- League moderators and platform moderators have explicitly different scope.
- Every view and action is audited; moderators cannot browse unrelated private
  conversations.
- Appeal/escalation and urgent safeguarding routes are documented.

#### LM-059 — Publish and enforce messaging standards

As a user, I need clear community rules and retention expectations before I post
so that acceptable behaviour and consequences are understood.

Acceptance:

- Users accept the current community standards before first posting after a
  material version change.
- Standards define objectionable content, harassment, privacy, impersonation,
  spam and prohibited sharing.
- Basic server-side content and rate safeguards are applied without claiming
  perfect automated moderation.
- Message, deletion, report and moderation-evidence retention are approved and
  implemented.
- Published support contact and response operation meet current App Store and
  Play user-generated-content requirements.

## Increment 6 — Migration, cutover and multi-sport scale

### Epic L6 — Safe adoption and reliable operation

#### LM-060 — Import a league from RackEm

As an adopting league, I need a controlled import so that teams, venues and
competition history do not have to be entered manually.

Acceptance:

- Import uses an approved API, export or authorised source method.
- Source identifiers, retrieval time and provenance are retained.
- Preview reports new, matched, conflicting and rejected records.
- No import overwrites an authoritative RooBin record silently.
- Repeat import is idempotent and supports source refresh before cutover.

#### LM-061 — Run a shadow season reconciliation

As a league committee, we need RooBin to reproduce an active season before it
becomes authoritative.

Acceptance:

- RooBin imports or receives the same teams, fixtures and final results as the
  incumbent system.
- Pairings, home/away allocations, tables, tie-breaks and knockout advancement
  are compared automatically.
- Differences identify whether the cause is configuration, input data, solver
  defect or authorised incumbent correction.
- Success thresholds and blocking discrepancies are agreed in advance.
- RooBin remains clearly labelled non-authoritative throughout the shadow run.

#### LM-062 — Cut a league over to RooBin authority

As a committee, we need an approved cutover and rollback plan so that a live
season is not put at unnecessary risk.

Acceptance:

- Cutover identifies scope, date, final source sync, data owner and support
  contacts.
- Captains, venues and league roles are verified before activation.
- Public links, result submission, notifications and exports are smoke-tested.
- The incumbent is retained read-only for the agreed comparison/rollback
  period where permitted.
- Go/no-go approval and post-cutover issues are recorded.

#### LM-063 — Govern ruleset and solver versions

As the platform operator, I need controlled template and algorithm releases so
that an upgrade cannot unexpectedly change a live competition.

Acceptance:

- Rulesets, match patterns, draw algorithms, travel calculators and scheduling
  solvers have independently recorded versions.
- A competition pins the versions used to generate or calculate its state.
- Upgrade previews identify changed outcomes before adoption.
- Security/defect fixes have an explicit policy for active competitions.
- Historical schedules and draws remain reproducible.

#### LM-064 — Monitor league automation quality

As the product owner, I need operational metrics so that automation is measured
by reduced administration and fair outcomes.

Acceptance:

- Metrics cover schedule generation time, infeasible plans, manual overrides,
  conflicts, travel distribution, home/away balance, notification delivery,
  acknowledgement and support demand.
- Pilot reporting records committee time saved and captain/venue satisfaction.
- Metrics distinguish sport, league size and competition format.
- Private messages, fine descriptions and unnecessary player data are excluded.

#### LM-065 — Enable direct player messaging safely

As an eligible player, I need an optional direct conversation so that necessary
one-to-one arrangements do not require exposing my personal contact details.

Acceptance:

- Direct messaging is enabled only for approved organisations/roles and after
  community-standards acceptance.
- Conversation creation respects block state, suspension and organisation
  relationship policy.
- Users can decline new direct conversations without leaving shared channels.
- Report, block, moderation, retention and rate-limit controls are live before
  the feature is enabled.
- Removing league/team membership follows the approved continuation or closure
  policy.

#### LM-066 — Add moderated message attachments

As a participant, I need approved files or images where operationally useful so
that scorecards and venue information can be shared safely.

Acceptance:

- Text-only messaging can release without this story.
- Allowed types, dimensions, size, malware scanning, metadata stripping and
  retention are configured server-side.
- Attachments use private authorised storage and expiring access URLs.
- Reporting and moderation preserve required evidence and can remove access.
- Images/video are not enabled until age, content-safety, storage and moderation
  operation are approved.

## Increment 7 — League finance and administration

### Epic L7 — Registration money and league operation

#### LM-070 — Configure league charges

As a league treasurer, I need to define team, player and competition charges so
that registration forms and invoices match the league's own fees.

Acceptance:

- Charges can be per team, per player, per entry or an approved combination.
- New registration, re-registration, late entry and competition charges can
  differ.
- Currency, tax display, effective period and refund policy are explicit.
- League charges are separate from RooBin's platform subscription catalogue and
  accounting.
- Historic registrations retain the amount and rule charged at the time.

#### LM-071 — Collect league registrations and entry fees

As a captain or entrant, I need to pay the configured league charge so that my
application can progress without manual cash tracking.

Acceptance:

- Checkout identifies the league as seller/recipient and RooBin's role in the
  transaction.
- Card, wallet and approved offline/bank-transfer states are supported according
  to league configuration and provider capability.
- Payment confirmation updates the correct registration idempotently.
- Payment does not bypass eligibility or committee approval.
- Processor fees and any approved platform transaction fee are shown and
  recorded transparently.

#### LM-072 — Invoice and reconcile offline league payments

As a treasurer, I need invoices and bank/cash reconciliation so that teams using
offline payment appear accurately alongside online payers.

Acceptance:

- An invoice/reference is unique within the league and season.
- Due, part-paid, paid, overdue, waived, cancelled and refunded states are
  supported.
- Manual receipt requires authorised treasurer action, amount, date, method and
  audit reason.
- Imports and duplicate references are reconciled rather than silently merged.
- RooBin never stores the league's online-banking credentials.

#### LM-073 — Refund and adjust league charges

As a league treasurer, I need credits, refunds and waivers recorded safely so
that registration and finance totals remain explainable.

Acceptance:

- Full/partial refund, credit, write-off and approved waiver are distinct.
- Provider refunds are verified and reconciled before final state.
- Financial adjustment does not automatically withdraw a team unless policy
  explicitly links those actions.
- Issued documents are corrected through adjustment records, not rewritten.
- Every adjustment requires authority and reason.

#### LM-074 — Report league finances

As a committee, we need season finance reports so that expected and received
registration income can be governed.

Acceptance:

- Reports cover charges, payments, outstanding, overdue, refunds, waivers,
  processor fees and net receipts.
- Results can be filtered by season, division, competition, team and payment
  state according to permission.
- Accounting export excludes private team fines and unrelated player data.
- Report totals reconcile to immutable transaction records.
- Platform subscription costs are shown separately from money collected for the
  league.

#### LM-075 — Manage league documents and policies

As a league administrator, I need to publish rules, forms and committee
documents so that everyone uses the current approved version.

Acceptance:

- Documents have category, version, effective date, visibility and owner.
- Current and archived versions remain identifiable by stable links.
- Material rules changes can require acknowledgement from defined roles.
- Private committee documents are excluded from public search and unauthorised
  storage access.
- Removed public content follows retention and link-handling policy.

#### LM-076 — Manage league branding and sponsors

As a league administrator, I need approved branding and sponsorship placements
so that the public league experience reflects its identity and funding.

Acceptance:

- Logo, colours, public contact and approved sponsor placements are supported
  within accessible design constraints.
- Sponsorship has start/end, destination, placement and approval state.
- Behavioural targeting and use of fine/message/player data are prohibited.
- Expired or removed sponsorship disappears without breaking historic results.
- Custom domains remain a separately priced/configured platform capability.

## Increment 8 — Platform integration and production operation

### Epic L8 — Open, recoverable and supportable service

#### LM-080 — Provide a versioned League API

As an authorised league or integration partner, I need stable APIs so that
fixtures, results and public data can be exchanged without scraping pages.

Acceptance:

- Read/write endpoints have versioned contracts, scopes and rate limits.
- Public, league-admin and service integrations use distinct authorisation.
- Idempotency is required for supported mutations.
- Deprecation and compatibility policy is published.
- API access cannot bypass membership, commercial entitlement or audit rules.

#### LM-081 — Publish outbound webhooks

As an integrated customer, I need signed event notifications so that external
systems can react to approved schedule and result changes.

Acceptance:

- Events include stable IDs, version, organisation, timestamp and minimal
  payload.
- Delivery is signed, retried with backoff and replay-safe.
- Customers can rotate secrets, inspect delivery attempts and replay authorised
  events.
- Private message and fine content is excluded from general league webhooks.
- Failed endpoints cannot block core league transactions.

#### LM-082 — Export league data

As a league owner, I need complete authorised exports so that data portability,
backup and exit do not depend on RooBin support.

Acceptance:

- Exports cover organisation, seasons, divisions, teams, venues, registrations,
  fixtures, results, standings, competitions and approved finance data.
- Private data and message exports require appropriate authority and purpose.
- Formats are documented, versioned and machine-readable.
- Large exports are generated asynchronously with secure expiry.
- Export does not mutate or mark records as deleted.

#### LM-083 — Back up and recover League data

As the platform owner, I need tested recovery so that a failure cannot destroy
an active competition.

Acceptance:

- Backups cover authoritative data, storage, configuration, audit and required
  secrets/configuration through approved secure mechanisms.
- Recovery point/time objectives are documented for paid League operation.
- Restore and point-in-time procedures are tested outside production.
- Realtime, notifications and webhooks resume without duplicating committed
  results or payments.
- Customers are informed according to the incident policy when recovery affects
  their data or service.

#### LM-084 — Operate platform administration and support

As support staff, I need least-privilege diagnostic tools so that league issues
can be resolved without unsafe database access or silent impersonation.

Acceptance:

- Support can inspect scoped configuration, jobs, notifications, imports and
  audit events according to role.
- Any support-assisted mutation requires explicit action, reason and audit.
- Impersonation is prohibited or implemented only through an approved,
  customer-visible, time-limited support session.
- Cross-organisation access is monitored and reviewed.
- Customers can reference support cases from affected league records.

#### LM-085 — Enforce privacy and retention across League data

As a participant, I need personal data handled consistently across seasons,
messages, results and public pages.

Acceptance:

- Data inventory and retention cover identities, registrations, eligibility,
  results, statistics, messages, moderation, notifications and finance.
- Public-name, historic-result and deletion/anonymisation policies are approved.
- Subject access, correction and deletion workflows include League data and
  explain lawful/contractual retention.
- Children/youth participation cannot be enabled without approved age,
  safeguarding and guardian requirements.
- Retention jobs are observable, idempotent and audited.

#### LM-086 — Meet production security and reliability gates

As a paying league, we need a secure and reliable platform so that automation
does not create an unacceptable operational dependency.

Acceptance:

- Threat modelling covers scheduling, result fraud, role escalation, imports,
  payments, messaging, webhooks and support access.
- RLS/authorisation matrices, rate limits, secret rotation and dependency
  scanning are tested.
- Load tests cover registration opening, fixture publication and match-night
  result/realtime peaks.
- Monitoring covers availability, latency, job queues, solver failures,
  notifications, payments and capacity.
- Accessibility and supported-browser/device tests cover public and authorised
  critical journeys.
- Incident response, on-call ownership and customer communication are tested.

#### LM-087 — Audit authoritative league actions

As a committee and platform operator, we need tamper-resistant action history so
that schedules, draws, results and permissions can be explained.

Acceptance:

- Audit covers roles, registrations, division allocation, schedules, draws,
  venues, results, disputes, finance, moderation, imports and support actions.
- Actor, authority, request correlation, before/after reference, reason and time
  are recorded where applicable.
- Sensitive secrets and unnecessary message content are excluded.
- Authorised exports and search support investigation without permitting audit
  mutation.
- Retention and access satisfy approved legal and operational policy.

## Recommended delivery path

1. Release RooBin Team independently at GBP 10 per team per season.
2. Complete LM-001 through LM-009 with one real pool league's roles, venues,
   registration and formats.
3. Deliver LM-010 through LM-016 as a Pool League Lite scheduling pilot.
4. Add configurable scorecards, eligibility, disputes, rollover and standings
   through LM-020 through LM-029.
5. Deliver auditable cup draws, dependency resolution and neutral-venue
   optimisation through LM-030 through LM-036.
6. Prove combined league/cup scheduling through LM-040 through LM-043.
7. Add league communication, public presentation and UGC safeguards through
   LM-050 through LM-059 and LM-065; keep LM-066 attachments optional.
8. Add league finance, documents and branding through LM-070 through LM-076.
9. Complete production integration and operation through LM-080 through LM-087.
10. Run LM-060 and LM-061 for a complete shadow season before offering LM-062
    cutover.
11. Validate a named darts league before implementing LM-025 and additional
    sport templates.

## Pilot acceptance threshold

RooBin League should not replace the incumbent for a complete league until it
can demonstrate, for the pilot league:

- all required league and cup rounds fit or infeasibility is correctly
  explained;
- every pairing, bye, home/away allocation and venue constraint is valid;
- neutral venue rankings are reproducible and policy-compliant;
- completed knockout dependencies advance exactly once;
- standings reconcile with the approved rules;
- captains and venues receive material schedule changes reliably;
- authorised overrides and corrections are fully auditable; and
- the committee approves the cutover and rollback plan.
