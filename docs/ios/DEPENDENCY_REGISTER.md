# iOS Dependency Register

Status: initial baseline  
Reviewed: 31 July 2026

Every direct and transitive dependency must be reviewed before it enters a
release build. Record its purpose, version policy, source, licence, maintenance,
data handling, privacy manifest, required-reason APIs, and removal plan.

## Current application dependencies

| Dependency | Source | Purpose | Data or privacy impact | Decision |
|---|---|---|---|---|
| SwiftUI | Apple SDK | Native interface and navigation | None beyond app behaviour | Approved |
| Foundation | Apple SDK | Core models and platform services | Review each API as used | Approved |
| Swift Testing | Apple SDK, test target only | Unit tests | Not shipped in app target | Approved |

The app target currently contains no third-party SDK.

## Build-only tooling

| Tool | Version | Purpose | Shipped in app |
|---|---:|---|---:|
| Xcode | 26.6 | Build, simulator, test and archive | No |
| XcodeGen | 2.46.0 | Reproducible `.xcodeproj` generation | No |

## Planned review

Supabase Swift is the only planned initial third-party runtime dependency. Do
not add it until IOS-012 defines the environment and API contract. Before
approval, record:

- exact pinned version and package checksum;
- transitive packages and licences;
- session-storage behaviour;
- networking and logging behaviour;
- included privacy manifests and required-reason APIs;
- release/signature provenance and maintenance status.

Analytics, advertising, crash-reporting, image-loading, and alternative
networking SDKs are not approved by default.
