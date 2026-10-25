# Contributing

Bug reports, documentation improvements and focused pull requests are welcome. For an API change, open an issue with a short usage example first.

## Getting started

Use the Xcode version in `.xcode-version`. Open `TMProgressHud.xcodeproj` for the library or the [example project](Examples/README.md) to try it in an app.

For local app integration, use Xcode's **Add Package Dependencies → Add Local**, or `pod 'TMProgressHudUIKit', :path => '../TMProgressHud'` in a Podfile.

```sh
./Scripts/check.sh
./Scripts/build-ios.sh
```

Run the hosted tests on both platforms before submitting a behavior change; commands and packaging checks are in [Testing](Docs/TESTING.md).

Use Apple’s `swift-format` and the pinned SwiftLint version; setup is in [Testing](Docs/TESTING.md). Formatting rules live in `.swift-format`, safety/metric rules in `.swiftlint.yml`.

Maintained Xcode projects use JSON (`project.xcproj`) and require Xcode 27+.

If you add a Swift file, register it in `Tests/Host/TMProgressHudTestHost.xcodeproj`. Regenerate the production project with `python3 Scripts/project-factory.py framework TMProgressHud.xcodeproj`. The source-registry check catches missing files.

## Code and tests

- Favor clear names, small responsibilities and named constants. Follow the [code standards](Docs/CODE_STANDARDS.md).
- Preserve the 1.0 behavior described in [compatibility notes](Docs/COMPATIBILITY.md). Compare fixes against the pinned reference.
- Add meaningful regression tests. Production executable line coverage must remain 100%; do not weaken assertions or exclude UI code.
- Document public API changes and update the changelog when behavior changes.

## Pull requests

Explain the problem, the resulting behavior and how you tested it. Include before/after images for visual changes, where practical, and mention anything you could not verify. Keep unrelated refactoring separate.

Follow the [code of conduct](CODE_OF_CONDUCT.md). Do not include credentials or private user data in reports. Contributions use the project's MIT license; retain attribution for borrowed code.
