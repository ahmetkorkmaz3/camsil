# Contributing guide

Thank you for your contribution to Camsil. This file describes the development setup, the test steps, and the pull request rules.

## Report a bug or make a suggestion

1. First, search for the same topic on the [Issues](https://github.com/ahmetkorkmaz3/camsil/issues) page.
2. Open a new issue. Write this information:
   - The macOS version and the Mac model (for example M1, M3 Pro).
   - The Camsil version: `defaults read /Applications/Camsil.app/Contents/Info.plist CFBundleShortVersionString`
   - The steps, the expected result, and the actual result.

Before a large change, open an issue and discuss the idea.

## Development setup

**Requirements:** a Mac with Apple Silicon, macOS 14 or later, and Xcode. Make Xcode the active developer directory:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

**Build and run:**

```sh
swift test                    # CamsilCore tests
scripts/bundle.sh             # creates build/Camsil.app and build/Camsil-<version>.zip
open build/Camsil.app
```

You can also open `Package.swift` in Xcode. Run the app from `build/Camsil.app`, because the app needs its Info.plist, its icon, and a stable signature.

**GPU tests:** The tests in `GPUTestCase` subclasses need a Metal device. A machine without one (for example a CI virtual machine) skips them.

**Shaders:** SwiftPM does not compile `.metal` files on the command line. `Package.swift` copies `Sources/CamsilCore/Shaders` as a resource, and `MetalContext` compiles the shaders at run time. You do not need the Metal Toolchain.

**Script check:** CI checks all scripts with `shellcheck`. Do the same check before you push:

```sh
brew install shellcheck
shellcheck scripts/*.sh install.sh
```

### Signing and the Screen Recording permission

macOS binds the Screen Recording permission to the signature of the app. An ad-hoc signature changes with each build. For this reason, macOS asks for the permission again after each ad-hoc build.

To prevent this prompt, sign with a local certificate:

1. Create the certificate one time: `scripts/make-signing-cert.sh`. If the certificate already exists and you have the `.p12` file, double-click the file to import it into the login Keychain.
2. Build: `scripts/bundle.sh`. The script finds the "Camsil Self-Signed" certificate by its name.

If macOS still asks for the permission, reset the entry: `tccutil reset ScreenCapture com.ahmetkorkmaz.Camsil`

## Project structure

| Folder | Content |
|---|---|
| `Sources/CamsilCore` | Logic and GPU code without AppKit windows: wipe rules, tool state, droplet physics, session state, Metal kernels, sound. The tests cover this module. |
| `Sources/CamsilCore/Shaders` | Metal shaders. `MetalContext` compiles them at run time. |
| `Sources/Camsil` | The AppKit app: overlay window, screen capture, permission flow, HUD, and the scene that connects them. |
| `Resources/` | App icon, bottle image, and the optional sounds in `Sounds/`. `scripts/bundle.sh` copies them into the app. |
| `Tests/CamsilCoreTests` | Unit and GPU tests. `TestGPU.swift` has the GPU helpers. |
| `assets/source/` | Source images. `scripts/cutout.swift` makes `Resources/bottle.png` from them. |
| `site/` | The website. GitHub Pages publishes this folder. |
| `docs/manual-test.md` | The manual test list to do before each release. |
| `docs/release.md` | Release steps. |
| `docs/superpowers/` | Design documents and plans. |
| `scripts/` | Build, icon, certificate, Open Graph image, and CHANGELOG scripts. |
| `install.sh` | Install and update script. |
| `.github/workflows/` | CI, release, and Pages workflows. |

## Code rules

- Write the logic in `CamsilCore`. The `Camsil` module contains only the app and the AppKit code.
- Add a test for each change in `CamsilCore`. For GPU code, subclass `GPUTestCase` and use the helpers in `TestGPU`.
- Put the tuning values in `Tuning.swift`.
- The app shows its texts in Turkish. Use short and clear sentences.
- Add a new sound only from a CC0 source, and list it in `CREDITS.md`.
- Follow the style of the code around your change.

## Commit messages

Write commit messages in English, in the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
feat: add a water spot type to the dirt
fix: keep the old app when the install copy fails
build: compile the shaders at run time, because SwiftPM does not compile .metal files
```

Types in use: `feat`, `fix`, `perf`, `docs`, `ci`, `build`, `test`, `refactor`, `chore`. The scope is optional: `core`, `app`, or `site`. When there is a reason, add it to the message with `because`.

## Pull requests

1. Create a new branch from `main`. Examples: `feat/fingerprints`, `fix/install-path`.
2. Make the change. Run `swift test` and `shellcheck`.
3. When the screen output changes, add a screenshot or a short video.
4. When the user can see the change, add a line to the `## [Unreleased]` section at the top of `CHANGELOG.md`.
5. Open the pull request. The review starts when CI passes.

## Website

The website is the `site/index.html` file. The page is one HTML file. It has no build step.

- To see it locally: `open site/index.html`
- When you push to the `main` branch, `.github/workflows/pages.yml` publishes the page.
- One time before the first publish: go to GitHub → Settings → Pages → Source and choose **GitHub Actions**.
- After you change the icon, run `scripts/make-icon.sh` and then `scripts/make-og-image.sh`.

## Releases

Release steps: [`docs/release.md`](docs/release.md). Before a release, do the steps in [`docs/manual-test.md`](docs/manual-test.md).

## License

Your contributions are published under the [MIT license](LICENSE).
