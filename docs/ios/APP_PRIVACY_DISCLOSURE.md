# RooBin App Privacy Disclosure

Status: owner approved 2 August 2026; ready for App Store Connect entry  
Reviewed: 2 August 2026

This is the conservative disclosure for RooBin v1. It covers the native app,
the backend services it calls, and the service providers used to fulfil those
requests. Do not omit a category merely because it is used only to provide the
app.

## Top-level App Store Connect answers

- Does this app or its third-party partners collect data? **Yes**
- Is any collected data used for tracking? **No**
- Is data used for third-party advertising? **No**
- Is data used for developer advertising or marketing? **No**
- Is data used for analytics? **No**
- Is data linked to the user? **Yes, for every declared category**
- Purpose for every declared category: **App Functionality**

## Categories to declare

| Apple category | Data type | Why RooBin collects it | Linked |
|---|---|---|---:|
| Contact Info | Name | player display name and invitation name | Yes |
| Contact Info | Email Address | authentication, invitations, recovery and security messages | Yes |
| Contact Info | Phone Number | existing player profile/contact field; SMS is not enabled in v1 | Yes |
| Financial Info | Other Financial Info | fine, subscription and paid/unpaid ledger amounts; RooBin does not process payments | Yes |
| User Content | Photos or Videos | user-selected team logo, converted to metadata-free JPEG before upload | Yes |
| User Content | Other User Content | team names, opponents, fixtures, fine types and team-entered records | Yes |
| Identifiers | User ID | authentication identity, player linkage and authorisation | Yes |
| Usage Data | Other Usage Data | narrowly scoped security/audit actions and abuse-prevention attempts | Yes |
| Diagnostics | Other Diagnostic Data | limited server/provider operational and error logs | Yes |

For each row choose **App Functionality** only, **Linked to the User: Yes**, and
**Used for Tracking: No**.

## Categories not collected by RooBin v1

- Physical address or other contact information
- Health, fitness or sensitive information
- Payment information or credit information
- Precise or coarse location
- Device contacts
- Emails or text-message content
- Audio data
- Browsing or search history
- Purchases
- Advertising data
- Device ID or advertising ID
- Environment, hand or head scanning

Apple may independently collect App Store or platform diagnostics; information
collected solely by Apple is not RooBin collection. If RooBin later adds an
analytics/crash SDK, SMS/WhatsApp, payments, location or messaging, review and
update this declaration before shipping that version.

## Privacy URLs

- Policy: `https://roobin.trovefinds.co.uk/privacy`
- Privacy choices and deletion: `https://roobin.trovefinds.co.uk/account-deletion`
- Support: `https://roobin.trovefinds.co.uk/support`

## Evidence

- `PrivacyInfo.xcprivacy` declares the same collected-data types, no tracking,
  no tracking domains, and the approved UserDefaults required-reason API.
- Native networking sends data only to the configured Supabase backend.
- The app target contains no advertising, analytics or third-party runtime SDK.
- PhotosPicker output is rendered as a bounded metadata-free JPEG before upload.
- Account deletion removes personal information and replaces retained historic
  shared-ledger attribution with a team-specific sport alias.

## Approved policy decisions

- Data controller: `Andy Thomas, operator of RooBin`.
- Operational logs: 30 days.
- Security audit records: 12 months.
- Immediate account deletion with no recovery period.
- Public RackEm fixture information is imported only at a team administrator's
  request; RooBin is not affiliated with RackEm.
