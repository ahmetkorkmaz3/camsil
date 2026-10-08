#!/bin/bash
# Usage: NOTARY_PROFILE=camsil-notary scripts/release.sh 1.0.0
set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version>}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a profile saved with xcrun notarytool store-credentials}"

BUILD=build/release
rm -rf "$BUILD"
mkdir -p "$BUILD"

xcodegen generate
xcodebuild -project Camsil.xcodeproj -scheme Camsil -configuration Release \
  -archivePath "$BUILD/Camsil.xcarchive" MARKETING_VERSION="$VERSION" archive -quiet

cat > "$BUILD/ExportOptions.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>developer-id</string>
  <key>signingStyle</key>
  <string>automatic</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive -archivePath "$BUILD/Camsil.xcarchive" \
  -exportOptionsPlist "$BUILD/ExportOptions.plist" -exportPath "$BUILD/export" -quiet

APP="$BUILD/export/Camsil.app"
ditto -c -k --keepParent "$APP" "$BUILD/Camsil.zip"
xcrun notarytool submit "$BUILD/Camsil.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"

DMG="$BUILD/Camsil-$VERSION.dmg"
hdiutil create -volname Camsil -srcfolder "$APP" -ov -format UDZO "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"

echo "Done: $DMG"
