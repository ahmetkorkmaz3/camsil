#!/bin/sh
# Builds build/Camsil.app and build/Camsil-<version>.zip with its .sha256 file, for GitHub Releases.
# VERSION sets the version (CI passes it from the tag). Without it, an exact v* tag gives the version,
# or the version is 0.0.0-dev.
# CODESIGN_IDENTITY names a certificate in the keychain. Without it, the script uses "Camsil Self-Signed"
# (made by scripts/make-signing-cert.sh) if the keychain has it, or else an ad-hoc signature.
# macOS binds the Screen Recording permission to the signature. An ad-hoc signature changes with each build,
# so macOS then asks for the permission again after each build.
# The app is arm64 only: the simulation textures use shared storage, which needs Apple Silicon.
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
DEFAULT_IDENTITY="Camsil Self-Signed"
if [ -n "${CODESIGN_IDENTITY:-}" ]; then
    IDENTITY="$CODESIGN_IDENTITY"
elif security find-certificate -c "$DEFAULT_IDENTITY" >/dev/null 2>&1; then
    IDENTITY="$DEFAULT_IDENTITY"
else
    IDENTITY="-"
fi

swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
APP="build/Camsil.app"
ZIP="build/Camsil-$VERSION.zip"

rm -rf "$APP" "$ZIP" "$ZIP.sha256"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Camsil" "$APP/Contents/MacOS/Camsil"
# MetalContext looks for the shader bundle in Contents/Resources. codesign rejects files in the app root.
ditto "$BIN_DIR/Camsil_CamsilCore.bundle" "$APP/Contents/Resources/Camsil_CamsilCore.bundle"
cp Resources/AppIcon.icns Resources/bottle.png "$APP/Contents/Resources/"
# The sounds are optional. Without them, the app is silent (see CREDITS.md).
for SOUND in Resources/Sounds/*.wav; do
    [ -e "$SOUND" ] && cp "$SOUND" "$APP/Contents/Resources/"
done

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>com.ahmetkorkmaz.Camsil</string>
    <key>CFBundleName</key><string>Camsil</string>
    <key>CFBundleDisplayName</key><string>Camsil</string>
    <key>CFBundleExecutable</key><string>Camsil</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleDevelopmentRegion</key><string>tr</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>© 2026 Ahmet Korkmaz. MIT License.</string>
</dict>
</plist>
PLIST

if [ "$IDENTITY" = "-" ]; then
    echo "Uyarı: Ad-hoc imza. Her derlemeden sonra macOS Ekran Kaydı iznini yeniden ister. Bkz. scripts/make-signing-cert.sh" >&2
fi
# Hardened runtime now, because notarization needs it later (docs/release.md).
codesign --force --options runtime --timestamp=none --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict "$APP"

ditto -c -k --keepParent "$APP" "$ZIP"
(cd build && shasum -a 256 "Camsil-$VERSION.zip" > "Camsil-$VERSION.zip.sha256")
echo "$APP ($VERSION)"
echo "$ZIP"
