# App Review handoff

Status: prepared draft; credentials and contact phone must be entered privately
in App Store Connect when the release candidate is ready.

## Release decisions

- Version 1.0 release: **manual release after approval**.
- Phased release: not applicable to the first public version; reconsider for
  later updates.
- Sign-in required: yes.
- Review environment: production-like backend that remains available throughout
  review.
- Payments: none. RooBin records team ledger amounts and payment status but does
  not collect or transfer money.

## Review contact

- Name: Andy Thomas
- Email: `hello@trovefinds.co.uk`
- Phone: enter the monitored contact number directly in App Store Connect.

Do not commit a personal phone number or review credentials to this repository.

## Dedicated review access

Prepare a dedicated email account and mailbox solely for App Review. The
reviewer must be able to receive RooBin's eight-digit email one-time code. Enter
the mailbox address and its temporary mailbox password only in App Store
Connect's protected review fields.

The prepared RooBin account should already belong to a fictional team and hold
the captain role so that role-dependent features are visible. Populate it with:

- at least four fictional players;
- one current season;
- draft and submitted home and away matches;
- fines and subscriptions in both paid and unpaid states;
- several fine types;
- a fictional team logo;
- a team unlock code supplied privately in the review notes.

Rotate or disable the review mailbox credentials and team unlock code after the
review window closes.

## App Review notes

RooBin is a private team and club ledger for matches, fines and subscriptions.
It does not process payments or sell digital goods.

Sign in using the dedicated review email account supplied in the protected
Sign-In Information fields. Select **Continue with email**, request a code, and
retrieve the eight-digit one-time code from that dedicated mailbox. The account
opens directly into a prepared fictional team with captain access.

Suggested review journey:

1. Home: inspect season totals, balances and player summaries.
2. Matches: open draft and submitted fixtures; create a draft if desired.
3. Fines: inspect the ledger and paid/unpaid states.
4. Settings: inspect roster roles, invitations, fine types, seasons, team
   settings and unlock security.
5. Privacy and support: open the privacy policy, terms and support pages.
6. Profile: account deletion is available in Settings and requires fresh email
   verification. A captain must transfer captaincy before deletion when other
   members remain; a sole member can delete the team and account together.

Protected operations require the dedicated team unlock code supplied privately
in App Store Connect review notes.

No external hardware, purchase, subscription, location access, contacts access,
camera, microphone or SMS/WhatsApp verification is required.

## Export compliance

The iOS client does not implement proprietary or non-standard cryptography. It
uses Apple platform networking for HTTPS and Apple Keychain services for secure
session storage. `ITSAppUsesNonExemptEncryption` is therefore declared `false`
in the app Info.plist. Reassess this answer if a dependency or feature later
adds cryptographic implementation outside the Apple operating system.

## Final pre-submission checks

- Confirm the dedicated mailbox and OTP delivery work immediately before
  submission.
- Confirm the prepared captain account opens the fictional review team.
- Confirm the unlock code works and is entered only in protected review notes.
- Confirm the backend, email sender, support URL, privacy policy and terms remain
  available throughout review.
- Enter the monitored review phone number.
- Select **Manually release this version**.
