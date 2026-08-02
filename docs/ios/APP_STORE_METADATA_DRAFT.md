# RooBin App Store Metadata

Status: implementation draft for App Store Connect entry  
Updated: 2 August 2026

## Product information

- Name: `RooBin`
- Subtitle: `The digital sin bin for teams`
- Primary category: `Sports`
- Secondary category: `Productivity`
- Bundle ID: `com.roobin.app`
- Minimum iOS: `17.0`
- Device family: iPhone
- Age rating recommendation: `9+`, reflecting possible infrequent crude humour
  in private team-created fine names
- Copyright: `© 2026 Andy Thomas`

## URLs

- Marketing: `https://roobin.trovefinds.co.uk/`
- Privacy policy: `https://roobin.trovefinds.co.uk/privacy`
- Support and account deletion: `https://roobin.trovefinds.co.uk/support`
- Terms: `https://roobin.trovefinds.co.uk/terms`

## Promotional text

Keep your team’s matches, fines, subs and balances together—without the
spreadsheet chase.

## Description

RooBin is the digital sin bin for teams and clubs.

Built for amateur pool teams, RooBin gives players and captains one shared
place to manage fixtures, match participation, fines, subscriptions, payment
status and team balances.

Use RooBin to:

- Create or join a team securely
- Plan and manage home and away matches
- Record fines and player subscriptions
- Track paid and unpaid balances
- Manage players, roles, seasons and fine types
- Import supported public fixture information
- Protect sensitive team actions with an additional unlock code

RooBin does not process payments. It helps your team maintain a clear shared
record of what has been agreed and paid.

## Keywords

`pool,team,fines,subs,matches,fixtures,club,players,balances,sport`

## Version 1.0 release notes

Welcome to RooBin. Create or join your team, manage matches, record fines and
subscriptions, and keep team balances clear in one secure shared app.

## App Review notes draft

RooBin uses email one-time codes for authentication. The reviewer can create a
new team after signing in; no payment or external hardware is required. RooBin
does not process money. Entries record amounts and payment status only.

Account deletion is available in Settings and requires fresh email
verification. Team captains may need to transfer captaincy before deleting an
account when other members remain. The only member of a team can delete the
team and account together.

Provide App Review with a dedicated test email account and a prepared team only
when the release candidate is ready. Never place a reusable team unlock code in
this tracked file; enter it directly in App Store Connect review notes.

The complete credential-free reviewer journey and private handoff checklist are
maintained in `APP_REVIEW_HANDOFF.md`. Version 1.0 will use manual release after
approval. The binary declares that it does not use non-exempt encryption; this
must be reassessed if custom cryptography is added.

## Screenshot plan

1. Home — season totals and balances
2. Matches — fixtures and match status
3. Match detail — participating players, fines and subs
4. Fines — clear player ledger and payment state
5. Team management — roster and settings

Capture with representative fictional names and data suitable for the 9+
rating. Do not include personal
email addresses, real invitation tokens, one-time codes or unlock codes.

The capture sequence, demo-data standard and final checks are maintained in
`APP_STORE_SCREENSHOT_RUNBOOK.md`. Four usable raw 1206 x 2622 framing captures
were retained on 2 August 2026; they are not final public assets because the
current staging team still contains test-oriented names and limited roster
data. The Matches-list capture was discarded because its staging fixture names
were not presentation quality.
