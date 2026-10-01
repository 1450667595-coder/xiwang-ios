#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodebuild >/dev/null || { echo 'This build requires macOS and Xcode.'; exit 1; }
xcodegen generate
plutil -lint XiWang/Info.plist
xcodebuild -project XiWang.xcodeproj -scheme XiWang -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' -derivedDataPath build/device \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO clean build
test -f build/device/Build/Products/Release-iphoneos/XiWang.app/XiWang
mkdir -p build/package/Payload artifacts
ditto build/device/Build/Products/Release-iphoneos/XiWang.app build/package/Payload/XiWang.app
(cd build/package && zip -qry ../../artifacts/XiWang-unsigned.ipa Payload)
unzip -t artifacts/XiWang-unsigned.ipa
shasum -a 256 artifacts/XiWang-unsigned.ipa > artifacts/SHA256SUMS.txt
echo 'Unsigned IPA prepared. Sign/install it with your own Apple account in Sideloadly.'
