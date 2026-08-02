# Deferred Actions

Status: active handoff register  
Updated: 1 August 2026

These items are intentionally deferred because they require the product owner,
desktop interaction, paid membership, or external approval. They are not
forgotten or silently assumed complete.

## When back at the Mac

- The populated-account Simulator checklist passed by 1 August 2026: profile,
  logo upload/immediate display, roster/role changes, invitations, fine types,
  seasons, member removal, unlock recovery, account deletion, core match/ledger
  regression and debug-isolated adverse states.
- Finish accessibility review. Maximum Dynamic Type passed across all primary
  screens after adaptive-layout fixes; Accessibility Inspector simulation,
  Bold Text, increased contrast and Reduce Motion also pass. Repeat
  representative checks on a small supported iPhone and true VoiceOver on a
  physical device.
- Run true VoiceOver gesture/audio journeys on a physical iPhone; Apple does not
  expose VoiceOver in iOS Simulator, which is limited to Accessibility Inspector
  audits and screen-reader simulation.
- Debug-isolated slow-network, staging-service outage and interrupted logo
  upload checks passed on 1 August 2026: delayed Home refresh
  and Matches loading completed without errors, frozen controls or duplicate
  data; the outage showed a retryable unavailable state, retained the saved
  session, exposed no team data, and recovered directly to Home when service
  returned. An upload interrupted after storage completed retained the prior
  team logo and relaunched normally; versioned objects prevent partial saves
  from replacing the active logo.
- Small-device layout and core navigation passed on the iPhone 17e Simulator on
  1 August 2026.
- The final 1024×1024 RooBin App Store icon was approved on 2 August 2026.
- Staging transactional-email delivery was confirmed on 2 August 2026 after
  publishing the monitoring-only DMARC policy for `trovefinds.co.uk`.
- In Supabase Auth > Email Templates, replace the staging Confirm Signup
  template with `supabase/templates/confirmation.html` and subject
  `Confirm your RooBin email`, then send and open a fresh invitation.

The iOS 26.5 Simulator is installed. The native project currently builds and
all ten Swift tests pass on the iPhone 17 Pro simulator.

## Before Sign in with Apple or distribution

- Activate the Apple Developer Program when ready.
- Record the actual Apple Team ID; do not reuse enrollment ID `8SC6V3W2FN`.
- Register bundle ID `com.roobin.app`.
- Configure the primary App ID, Sign in with Apple capability, Services ID,
  domains, return URLs and `.p8` key.
- Store the key server-side and establish six-month client-secret rotation.
- Create the App Store Connect record and later TestFlight configuration.

## External service configuration

- Create/approve Google Cloud OAuth clients for web, iOS and future Android.
- Complete Google consent/brand verification where required.
- Configure production and staging callback URLs separately.
- Confirm production Resend domain/sender and processor terms.
- Keep Twilio/WhatsApp/SMS deferred unless IOS-090 is deliberately reopened.

## Product and policy approval

- Enter the verified privacy-policy, support/account-deletion, marketing and
  terms URLs in App Store Connect when the app record exists.
- RackEm public-source provenance wording and v1 inclusion were approved on
  2 August 2026; re-review if RackEm access or terms change.
- Confirm ownership/clearance of the RooBin name, logo and supplied artwork.

Account-deletion policy is approved, its native/server implementation is
deployed to staging, and populated-account Simulator acceptance passed.

## Engineering gates

- Replace remaining legacy direct privileged web writes with approved
  server-owned contracts.
- Configure signing only after the real Team ID is known.
- Push the working branch so the new web, backend and iOS CI workflows execute
  on GitHub; resolve any runner-specific failures before TestFlight.
