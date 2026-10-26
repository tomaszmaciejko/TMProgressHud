# Testing

Use the Xcode version in `.xcode-version`. Maintained projects use JSON and require Xcode 27+. Disposable distribution consumers use the legacy format for CocoaPods and older-compiler checks; this does not change the library’s Swift 6.0 requirement. Install SwiftLint matching `.swiftlint-version` before running the local checks (`brew install swiftlint` when Homebrew provides that version, or use the matching official portable release). The manual workflow contains the checksum-verified portable installation. `Scripts/lint.sh` accepts `SWIFTLINT_BIN` or finds `.build/Tools/swiftlint` and then your PATH. The formatter is included in Xcode.

Start with:

```sh
./Scripts/check.sh
./Scripts/build-ios.sh
```

## Hosted tests

After adding or removing Swift sources, update the explicit project registries:

```sh
python3 Scripts/project-factory.py test-sources Tests/Host/TMProgressHudTestHost.xcodeproj
python3 Scripts/project-factory.py framework TMProgressHud.xcodeproj
```

The source verifier rejects missing, stale or duplicate registrations.

Hosted tests require iOS 17+ or tvOS 17+; the development library targets iOS 17 and tvOS 17. Replace the UUIDs below with dedicated test devices from `xcrun simctl list devices available`:

```sh
TMHUD_TEST_DESTINATION='platform=iOS Simulator,id=<UUID>' ./Scripts/test.sh
TMHUD_TEST_DESTINATION='platform=tvOS Simulator,id=<UUID>' ./Scripts/test.sh
```

The scripts boot the selected simulator, run tests and enforce 100% executable production line coverage. Results and coverage reports are written under `.build/`. Reports are tied to source hashes; stale reports fail the gate. Declaration-only files with no compiler coverage regions are individually accounted for in `Scripts/coverage-unmapped.json`.

Regression tests cover the development contract and compare preserved behavior with the pinned Objective-C implementation. Circular drawing remains byte-identical at the default size; enlarged-image comparisons bound the sparse antialiasing changes caused by native CGFloat precision. `Scripts/verify-reference.py` checks its checksums and the API inventory in `Tests/ReferenceAPI/api-inventory.json`. The reference is never linked into the shipped library.

## Packaging checks

```sh
./Scripts/build-xcframework.sh
pod lib lint TMProgressHudUIKit.podspec --platforms=ios,tvos --swift-version=6.0 --skip-tests --fail-fast
carthage build --no-skip-current --use-xcframeworks --platform iOS,tvOS
```

The framework builder requires a fresh output folder; set `TMHUD_ARTIFACT_DIR` to choose one. For an older compiler, set `TMHUD_PROJECT_FORMAT=plist` to generate a temporary compatible framework project under `.build/`. The shared `TMProgressHudUIKit` scheme builds the shipping framework; the framework under `Tests/Host` is test-only.

Build an independent consumer for either platform:

```sh
python3 Scripts/check-distribution.py spm --platform ios
python3 Scripts/check-distribution.py cocoapods --platform ios
python3 Scripts/check-distribution.py binary --platform ios --artifact Artifacts/TMProgressHudUIKit.xcframework
python3 Scripts/check-distribution.py carthage --platform ios --artifact Carthage/Build/TMProgressHudUIKit.xcframework
```

Repeat with `--platform tvos`. Add `--simulator-id <UUID>` to install and run a consumer's mode/action checks. SPM and CocoaPods also accept `--source-url <Git URL> --revision <full commit>` to test a remote checkout. Reports record the checked local/artifact input or exact remote commit; they make no claim about release publication. A new execution invalidates its previous success report, and writes `validation.json` only after verification succeeds.

For a signed release, verify its signature against the published certificate fingerprint:

```sh
python3 Scripts/audit-xcframework.py Artifacts/TMProgressHudUIKit.xcframework --require-signature --expected-certificate-sha256 "$(cat Certificates/TMProgressHud-signing.fingerprint)"
```

Run the local checks above during development. GitHub Actions workflows run only when a maintainer starts them manually, for release qualification or a targeted environment check. Pushes, pull requests and tags do not start CI.

The manual **Library checks** workflow checks the oldest supported compiler, current iOS/tvOS behavior and coverage, DocC and all four distributions. It builds the binary with Swift 6.0 before consuming it with the current compiler. Automated tests do not replace visual, VoiceOver or physical-device checks.

The manual **Minimum iOS runtime** workflow runs the six-mode/action consumer on the selected iOS 17 runtime using macOS 15 and Xcode 16.4. It defaults to iOS 17.0; this updated configuration has not yet been executed. The `release/1.x` branch retains the iOS 15 workflow.

Before packaging, run `python3 Scripts/verify-release-metadata.py` with SwiftPM and CocoaPods available. It compares versions and minimum systems across evaluated manifests, maintained projects and generated distribution projects, without building or resolving dependencies. The regular static checks run its fixture tests without requiring CocoaPods.
