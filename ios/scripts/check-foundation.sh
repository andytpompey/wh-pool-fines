#!/bin/zsh
set -euo pipefail

script_dir=${0:A:h}
ios_dir=${script_dir:h}
repository_dir=${ios_dir:h}

cd "$ios_dir"
xcodegen generate
plutil -lint RooBin/Resources/PrivacyInfo.xcprivacy

swift_sources=("${(@f)$(find RooBin -type f -name '*.swift' | sort)}")
swiftc -parse "${swift_sources[@]}"

xcodebuild -project RooBin.xcodeproj -list
git -C "$repository_dir" diff --check -- .gitignore ios docs/ios

if rg -n \
  'SUPABASE_SERVICE_ROLE_KEY|RESEND_API_KEY|TWILIO_AUTH_TOKEN|BEGIN PRIVATE KEY' \
  RooBin project.yml; then
  print -u2 "Potential server-side secret found in iOS source."
  exit 1
fi

print "RooBin foundation checks passed."
