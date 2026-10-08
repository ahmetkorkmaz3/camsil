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

## Release

Prerequisites:

- XcodeGen (`brew install xcodegen`).
- A Developer ID Application certificate in your keychain.
- A notary profile saved with `xcrun notarytool store-credentials` (for example `camsil-notary`).

    NOTARY_PROFILE=camsil-notary scripts/release.sh 1.0.0

Sound credits are in `CREDITS.md`.
