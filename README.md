# Camsil

Camsil needs a Mac with Apple Silicon (M1 or later) and macOS 14 or later.

Your screen is a dirty window. Spray it, wipe it, make it shine.

## Use

1. Open Camsil. Give Screen Recording permission on the first start, then open Camsil again.
2. Left click: spray. Right click or Space: change between bottle and cloth. 1 and 2 also select a tool.
3. Wipe wet glass with the cloth. Dry wiping only spreads the dust.
4. Esc or Cmd+Q closes Camsil at any time. Camsil also closes after 2 minutes without input.

## Build

    brew install xcodegen
    xcodegen generate
    xcodebuild -project Camsil.xcodeproj -scheme Camsil build

Put your team ID in `Config/Local.xcconfig` (`DEVELOPMENT_TEAM = ...`). A stable signature keeps the Screen Recording permission between builds.

- A free Apple ID "Personal Team" works for `DEVELOPMENT_TEAM`. Open Xcode > Settings > Accounts, add the Apple ID, then copy the team ID into `Config/Local.xcconfig`.
- If macOS keeps asking for Screen Recording after a rebuild, reset the entry with `tccutil reset ScreenCapture com.ahmetkorkmaz.Camsil`, then open Camsil again.
- The Metal Toolchain is needed once per Mac: `xcodebuild -downloadComponent MetalToolchain`.

## Test

    xcodebuild test -project Camsil.xcodeproj -scheme Camsil -destination 'platform=macOS'

GPU tests need an Apple Silicon Mac.

## Install

    curl -fsSL https://raw.githubusercontent.com/ahmetkorkmaz3/Camsil/main/install.sh | sh

`CAMSIL_VERSION=1.0.0` installs that version. The app is not notarized. `install.sh` downloads with curl, so macOS does not block it.

## Release

1. Build the app and the zip file:

        VERSION=1.0.0 scripts/bundle.sh

2. Publish `build/Camsil-1.0.0.zip` and `build/Camsil-1.0.0.zip.sha256` as release `v1.0.0`:

        gh release create v1.0.0 build/Camsil-1.0.0.zip build/Camsil-1.0.0.zip.sha256

macOS binds the Screen Recording permission to the signature. Run `scripts/make-signing-cert.sh` once. It puts a "Camsil Self-Signed" certificate in the login keychain, and `bundle.sh` then uses it. Without the certificate, the app gets an ad-hoc signature, and macOS asks for the permission again after each build.

Sound credits are in `CREDITS.md`.
