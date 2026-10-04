#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

rm -rf build
mkdir -p build/Payload

xcodebuild   -project SwiftChatDemo.xcodeproj   -scheme SwiftChatDemo   -configuration Release   -sdk iphoneos   -destination 'generic/platform=iOS'   -derivedDataPath build/DerivedData   CODE_SIGNING_ALLOWED=NO   CODE_SIGNING_REQUIRED=NO   CODE_SIGN_IDENTITY=""   build

APP_PATH="build/DerivedData/Build/Products/Release-iphoneos/SwiftChatDemo.app"
cp -R "$APP_PATH" build/Payload/
(
  cd build
  zip -qry SwiftChatDemo-unsigned.ipa Payload
)

echo "Created: $ROOT/build/SwiftChatDemo-unsigned.ipa"
