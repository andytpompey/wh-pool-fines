# RooBin iOS

Native SwiftUI client for RooBin. The React/Vite web application and Supabase
database remain separate, supported parts of the product.

## Requirements

- Xcode 26.6 or later
- XcodeGen 2.46 or later
- iOS 26.5 Simulator runtime for local verification

The deployment target is iOS 17 and the v1 device family is iPhone. The project
does not contain a development team or distribution-signing configuration.

## Generate and verify

From the repository root:

```sh
cd ios
xcodegen generate
xcodebuild \
  -project RooBin.xcodeproj \
  -scheme RooBin \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

Checks that do not require a Simulator runtime:

```sh
ios/scripts/check-foundation.sh
```

Do not add Supabase service-role keys, Apple private keys, OAuth client secrets,
OTP values, unlock codes, or other secret material to this directory. Public
client configuration will be supplied through environment-specific build
configuration in a later story.
