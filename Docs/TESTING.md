# Testing

Use the Xcode version in `.xcode-version`. Start with:

```sh
./Scripts/check.sh
./Scripts/build-ios.sh
```

## Hosted tests

Hosted tests require iOS 17+ or tvOS 17+; the shipping library still targets iOS/tvOS 15. Replace the UUIDs below with dedicated test devices from `xcrun simctl list devices available`:

```sh
TMHUD_TEST_DESTINATION='platform=iOS Simulator,id=<UUID>' ./Scripts/test.sh
TMHUD_TEST_DESTINATION='platform=tvOS Simulator,id=<UUID>' ./Scripts/test.sh
```

The scripts boot the selected simulator, run tests and enforce 100% executable production line coverage. Results and coverage reports are written under `.build/`. Reports are tied to source hashes; stale reports fail the gate. Declaration-only files with no compiler coverage regions are individually accounted for in `Scripts/coverage-unmapped.json`.

Tests compare the Swift port with the pinned Objective-C implementation. `Scripts/verify-reference.py` checks its checksums and the API inventory in `Tests/ReferenceAPI/api-inventory.json`. The reference is never linked into the shipped library.

## Packaging checks

```sh
./Scripts/build-xcframework.sh
pod lib lint TMProgressHudUIKit.podspec --platforms=ios,tvos --swift-version=6.0 --skip-tests --fail-fast
carthage build --no-skip-current --use-xcframeworks --platform iOS,tvOS
```

The framework builder requires a fresh output folder; set `TMHUD_ARTIFACT_DIR` to choose one. The shared `TMProgressHudUIKit` scheme builds the shipping framework; the framework under `Tests/Host` is test-only.

Build an independent consumer for either platform:

```sh
python3 Scripts/check-distribution.py spm --platform ios
python3 Scripts/check-distribution.py cocoapods --platform ios
python3 Scripts/check-distribution.py binary --platform ios --artifact Artifacts/TMProgressHudUIKit.xcframework
python3 Scripts/check-distribution.py carthage --platform ios --artifact Carthage/Build/TMProgressHudUIKit.xcframework
```

Repeat with `--platform tvos`. Add `--simulator-id <UUID>` to install and run a consumer's mode/action checks. SPM and CocoaPods also accept `--source-url <Git URL> --revision <full commit>` to test a remote checkout.

For a signed release, verify its signature against the published certificate fingerprint:

```sh
python3 Scripts/audit-xcframework.py Artifacts/TMProgressHudUIKit.xcframework --require-signature --expected-certificate-sha256 "$(cat Certificates/TMProgressHud-signing.fingerprint)"
```

Run the local checks above during development. GitHub Actions workflows run only when a maintainer starts them manually, for release qualification or a targeted environment check. Pushes, pull requests and tags do not start CI.

The manual **Library checks** workflow checks the oldest supported compiler, current iOS/tvOS behavior and coverage, DocC and all four distributions. It builds the binary with Swift 6.0 before consuming it with the current compiler. Automated tests do not replace visual, VoiceOver or physical-device checks.

The manual **Minimum iOS runtime** workflow runs the six-mode/action consumer on iOS 15.5 using macOS 15 and Xcode 16.4. iOS 15.0 can be selected for diagnostics, but its runtime is rejected by this host before application launch.
