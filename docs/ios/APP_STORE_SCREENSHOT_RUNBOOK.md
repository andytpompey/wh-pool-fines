# App Store screenshot runbook

## Target set

Capture portrait screenshots on the iPhone 17 Pro simulator at 1206 x 2622
pixels. Use a dedicated fictional review team with no personal email addresses,
codes, tokens or real player data visible.

Recommended public sequence:

1. Home dashboard — season overview, balances and representative team branding.
2. Matches — a mixture of clearly named upcoming, draft and submitted fixtures.
3. Match detail — players, drivers, fines and subs for one submitted fixture.
4. Fines ledger — several players and a useful mixture of paid and unpaid entries.
5. Team management — roster roles and the main captain controls.

## Demo data standard

- Team: a fictional club name rather than a name containing "Demo" or "Test".
- Opponents: realistic fictional club names with no spelling errors.
- Players: at least four fictional display names.
- Season: one named current season.
- Ledger: enough entries to demonstrate totals, collection rate and filters.
- Branding: a fictional team logo that is suitable for the 9+ age rating.
- Dates: internally consistent and representative of the release period.

## Raw framing captures

The files under `app-store-screenshots/raw/` confirm layout and the required
device dimensions. They are not final public assets because the staging data
contains test-oriented names and too little roster variety.

## Final checks

- Verify every image is 1206 x 2622 pixels and contains no simulator chrome.
- Check spelling, dates, currency, totals and payment states.
- Check the status bar contains no unexpected recording, VPN or location state.
- Confirm no email address, one-time code, unlock code or invitation data appears.
- Review the ordered set together at full size before upload to App Store Connect.
