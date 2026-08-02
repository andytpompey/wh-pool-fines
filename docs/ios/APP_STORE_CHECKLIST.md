# App Store and Release Checklist

Status: living checklist; not yet submission-ready  
Last verified against official Apple sources: 31 July 2026

Apple changes requirements. Recheck every linked source before external
TestFlight and again before submission.

## 1. Developer and application identity

- [x] Intended Apple Developer ownership is recorded as the individual account
      `Andy Thomas`.
- [ ] Paid membership is activated and the actual signing Team ID is recorded;
      enrollment ID `8SC6V3W2FN` must not be used for signing.
- [ ] Apple Developer Program membership is confirmed active.
- [ ] Agreements, tax, and banking are current if monetisation is introduced.
- [x] Installed/App Store name `RooBin`, subtitle `The digital sin bin for
      teams`, and full marketing proposition are confirmed.
- [ ] Ownership of the RooBin name and brand/artwork is confirmed.
- [ ] Bundle identifier `com.roobin.app` is final; registration in Apple
      Developer remains to be completed.
- [ ] App record, SKU, primary language, category, and age-rating answers exist.
- [ ] Updated 2026 age-rating questions are completed.
- [ ] Copyright and third-party rights, including RackEm names/data and team
      logos, are documented.

## 2. Build requirements

- [ ] Release is built with the then-current required Xcode and SDK.
- [ ] At review date baseline: Xcode 26+ and iOS 26 SDK+ are required for upload.
- [x] Deployment target is iOS 17 and the v1 device family is iPhone only.
- [ ] Portrait-first layouts remain usable in landscape on every supported
      iPhone size.
- [ ] Release archive contains no development URLs, test credentials, service
      keys, verbose logging, or debug menus.
- [ ] Version and build numbers are correct.
- [ ] Signing, entitlements, capabilities, and provisioning are minimal.
- [x] Export-compliance answer is documented and the current binary declares no
      non-exempt encryption; reassess if cryptographic dependencies change.
- [ ] Privacy manifest validation passes for app and third-party SDKs.
- [ ] Required-reason APIs use only approved, accurate reasons.
- [ ] All embedded SDKs requiring signatures/privacy manifests comply.

Official references:

- [Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)
- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Required-reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)

## 3. App completeness and review access

- [ ] No placeholder, unfinished, hidden, broken, or dead-end production flow.
- [ ] Production backend and required integrations remain live throughout review.
- [ ] Stable review account or Apple-approved fully featured demo mode is ready.
- [ ] Review team has sample team, seasons, matches, fines, and role-specific
      access sufficient to inspect the application.
- [ ] Non-obvious role, unlock, RackEm, and account-deletion steps are included in
      App Review notes.
- [ ] Contact person and reachable phone/email are current.
- [ ] Known external dependency behaviour and fallback are explained.
- [ ] All URLs are final and functional.

Reference: [App Review Guidelines, including 2.1 App
Completeness](https://developer.apple.com/app-store/review/guidelines/)

## 4. Authentication

- [ ] Account-based functionality justifies mandatory sign-in.
- [ ] Email OTP request, expiry, resend, error, and account recovery work.
- [ ] OTP responses do not enumerate accounts.
- [ ] Native Sign in with Apple uses Authentication Services and nonce
      validation.
- [ ] Web Sign in with Apple uses the registered Services ID, HTTPS domains, and
      exact return URLs.
- [ ] Sign in with Google uses approved web/iOS OAuth clients and exact redirect
      configuration.
- [ ] Apple/Google identities link to the canonical account without duplicating
      the player, memberships, or history.
- [ ] Linking/unlinking requires recent authentication and cannot remove the
      final usable sign-in/recovery method.
- [ ] Conflicting identities fail safely without account enumeration or an
      automatic destructive merge.
- [ ] Session revocation, expiry, sign-out, and device cache clearing work.
- [ ] Guideline 4.8 is reassessed against the final provider set.
- [ ] Apple token revocation is part of account deletion.
- [ ] Apple OAuth client-secret expiry is monitored and rotation is rehearsed
      before the six-month deadline.
- [ ] WhatsApp/SMS authentication is absent from v1 release builds and metadata.

Reference: [App Review Guideline
4.8](https://developer.apple.com/app-store/review/guidelines/#login-services)

## 5. Account deletion and privacy choices

- [ ] Delete Account is easy to find inside the app.
- [ ] It deletes the complete account rather than only deactivating it.
- [ ] Reauthentication and confirmation do not create unnecessary friction.
- [ ] Sole-captain/team ownership consequences are resolved.
- [ ] Associated personal content is deleted unless a documented legal
      requirement permits retention.
- [ ] Retained/anonymised data and timing are explained.
- [ ] Supabase Auth user and active sessions are deleted/revoked.
- [ ] Stored logos, invites, identifiers, caches, and processor data are handled.
- [ ] All users can use the deletion journey regardless of location.
- [ ] A direct web deletion link is provided if any required completion step is
      web-based.

References:

- [Offering account deletion](https://developer.apple.com/support/offering-account-deletion-in-your-app)
- [App Review Guideline
5.1.1](https://developer.apple.com/app-store/review/guidelines/#data-collection-and-storage)

## 6. Privacy policy and App Store privacy

- [ ] Public HTTPS privacy-policy URL is entered in App Store Connect.
- [x] The same policy is easily accessible inside the app.
- [x] Policy identifies collected data, collection method, purpose, sharing and
      processors, safeguards, retention/deletion, consent withdrawal, and contact.
- [x] User Privacy Choices URL is supplied if useful.
- [x] Data-flow inventory covers Supabase, storage, notification providers,
      RackEm, server logs, Apple diagnostics, and every SDK.
- [ ] App Privacy answers disclose all collected data and purposes, even when
      used only for app functionality, unless Apple’s complete optional-disclosure
      criteria genuinely apply.
- [x] Linked-to-user and tracking answers are accurate.
- [x] No tracking occurs without ATT consent; preferably no tracking SDK exists.
- [ ] Processor contracts and retention align with the published policy.
- [ ] Privacy answers are updated if behaviour changes after launch.

References:

- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)

## 7. Permissions and data minimisation

- [ ] App requests only capabilities needed for an immediate user action.
- [ ] Every purpose string is specific and user-centred.
- [ ] Team logo uses PhotosPicker without broad library access where possible.
- [ ] A denied permission has a reasonable fallback where possible.
- [ ] Push notification permission, if added, is requested in context and is not
      required for core use.
- [ ] No contacts, location, microphone, camera, Bluetooth, tracking, or local
      network permission is present without an approved feature and disclosure.
- [ ] Sensitive input uses native secure controls and is not logged.

## 8. Security

- [ ] Service-role keys and provider secrets exist only server-side.
- [ ] RLS role/status/cross-team test matrix passes.
- [ ] Privileged and protected actions are enforced server-side.
- [ ] Unlock hash/salt are not readable by clients; rate limits are server-side.
- [ ] Account and player identity linking cannot be hijacked.
- [ ] Aggregate and destructive mutations are transactional and idempotent.
- [ ] Audit events are authoritative, redacted, retained, and access-controlled.
- [ ] HTTPS is universal; no broad ATS exception.
- [ ] Credentials use the approved Keychain/Supabase secure-session mechanism.
- [ ] User-scoped cache is purged on sign-out, deletion, and membership removal.
- [ ] Dependency, secret, and static security scans pass.
- [ ] Security/contact reporting route exists.

## 9. User interface and accessibility

- [ ] App uses native, consistent iOS navigation and controls.
- [ ] No screen is merely a wrapped website.
- [ ] All interactive targets are at least 44 × 44 points.
- [ ] Dynamic Type works through accessibility sizes without clipped content.
- [ ] VoiceOver labels, values, hints, headings, and order are verified.
- [ ] Paid/unpaid, role, success, warning, and error do not rely on colour alone.
- [ ] Contrast is sufficient in the branded dark appearance.
- [ ] Reduce Motion, Bold Text, and Increase Contrast are respected.
- [ ] Keyboard and switch-control behaviour are reasonable.
- [ ] Destructive actions explain impact and require confirmation.
- [ ] Loading, empty, offline, stale, forbidden, and error states are complete.

Reference: [Apple Human Interface
Guidelines](https://developer.apple.com/design/human-interface-guidelines)

## 10. Content and product behaviour

- [ ] Fine names, team/player content, and imported content have reporting/support
      handling appropriate to the actual user-generated-content model.
- [ ] App does not encourage harassment or public humiliation.
- [ ] Money displayed is a team ledger, not represented as regulated payment,
      gambling, lottery, or real-money gaming unless legal/product review says
      otherwise.
- [ ] No digital goods or paid features bypass In-App Purchase rules.
- [ ] If monetisation is added, Guideline 3.1 is assessed before implementation.
- [ ] RackEm outage does not prevent manual core use.
- [ ] Third-party marks and content permissions are documented for review.

## 11. Quality assurance

- [ ] Backend migration rehearsal succeeds from production-like data.
- [ ] Web regression tests pass against final shared schema.
- [ ] iOS unit, integration, and UI tests pass.
- [ ] Smallest and largest supported iPhones pass on-device testing.
- [ ] Current public iOS and minimum supported iOS pass.
- [ ] Slow/offline/interrupted/retry states do not duplicate or corrupt data.
- [ ] Background/foreground, session expiry, low storage, upload failure, and
      external-service outage pass.
- [ ] Fresh install, update, sign-out/in, account deletion, and reinstall pass.
- [ ] No known crash, data loss, cross-team access, or privacy defect remains.

## 12. App Store metadata

- [ ] Name, subtitle, description, keywords, promotional text, and release notes
      are accurate and do not promise unavailable functionality.
- [ ] App icon and screenshots use final production UI and 9+-appropriate imagery.
- [ ] Required screenshot sizes/device sets are complete.
- [x] Support URL and marketing URL are live.
- [x] Privacy policy URL is live.
- [x] Recommended age-rating answers are documented and content-rights answers
      are correct; enter them in App Store Connect when the app record exists.
- [ ] App Review contact, demo credentials, notes, and attachments are complete.
- [x] Version 1.0 manual release decision is recorded; phased release applies to
      later updates rather than the first public version.

References:

- [Submit an app](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-app)
- [App Review overview](https://developer.apple.com/app-store/review/)

## 13. TestFlight gates

### Internal

- [ ] P0 findings are closed or native writes remain isolated to mock/staging.
- [ ] Privacy manifest and beta data practices are accurate.
- [ ] Test data is non-sensitive.
- [ ] Feedback and incident channels are defined.

### External

- [ ] All P0 and P1 findings are closed.
- [ ] Beta App Review information is complete.
- [ ] Privacy policy and account deletion are functional.
- [ ] Representative members, vice-captains, and captains pass primary journeys.
- [ ] Release candidate migration has rollback/recovery planning.

## 14. Final submission sign-off

- [ ] Product owner
- [ ] Engineering
- [ ] Security/privacy
- [ ] Accessibility/QA
- [ ] App Store metadata owner
- [ ] Support/operations
- [ ] Legal review where required

Submission is blocked by any unchecked P0/P1 security item, missing account
deletion, inaccurate privacy disclosure, inaccessible core journey, unavailable
review backend/account, or build that fails Apple’s current SDK requirements.
