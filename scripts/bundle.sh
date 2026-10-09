#!/bin/sh
# Builds build/Camsil.app and build/Camsil-<version>.zip with its .sha256 file, for GitHub Releases.
# VERSION sets the version. Without it, an exact v* tag gives the version, or the version is 0.0.0-dev.
# CODESIGN_IDENTITY names a certificate in the keychain (for example a self-signed one).
# Without it, the app gets an ad-hoc signature. Then macOS asks for Screen Recording again after each update.
# The app is not notarized, because that needs a paid Apple Developer account.
set -eu
cd "$(dirname "$0")/.."

if [ -z "${VERSION:-}" ]; then
    TAG="$(git describe --tags --exact-match 2>/dev/null || true)"
    case "$TAG" in
        v[0-9]*) VERSION="${TAG#v}" ;;
        *) VERSION="0.0.0-dev" ;;
    esac
fi
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
IDENTITY="${CODESIGN_IDENTITY:--}"

command -v xcodegen >/dev/null 2>&1 || { echo "Hata: XcodeGen yok. Kurun: brew install xcodegen" >&2; exit 1; }

DERIVED="build/dd-release"
APP="build/Camsil.app"
ZIP="build/Camsil-$VERSION.zip"

xcodegen generate --quiet
# Xcode does not sign here. The script signs below, so the signature does not need an Apple team.
xcodebuild -project Camsil.xcodeproj -scheme Camsil -configuration Release \
    -derivedDataPath "$DERIVED" -destination 'generic/platform=macOS' \
    MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGNING_ALLOWED=NO build -quiet

rm -rf "$APP" "$ZIP" "$ZIP.sha256"
ditto "$DERIVED/Build/Products/Release/Camsil.app" "$APP"

if [ "$IDENTITY" = "-" ]; then
    echo "Uyarı: Ad-hoc imza. Her güncellemeden sonra macOS Ekran Kaydı iznini yeniden ister." >&2
fi
# No hardened runtime: it is only for notarization, and its library check can reject
# an embedded framework that has no Apple team ID.
# Sign from the inside out: the framework first, then the app.
codesign --force --timestamp=none --sign "$IDENTITY" "$APP/Contents/Frameworks/CamsilCore.framework"
codesign --force --timestamp=none --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"
(cd build && shasum -a 256 "Camsil-$VERSION.zip" > "Camsil-$VERSION.zip.sha256")
echo "$APP ($VERSION)"
echo "$ZIP"
