# Changelog

## 2.0.0 (Unreleased)

- Raise the minimum iOS and tvOS versions to 17.0.
- Use UIKit’s duration/bounce spring animations, with a perceived duration of 0.3 seconds and no bounce.
- Refresh custom indicator drawing and action-button border colors when color appearance traits change.
- Follow host resizing through UIKit layout instead of global status-bar orientation notifications.
- Preserve app-added constraints during layout updates and reuse layout constraints when only parameters change.
- Store maintained Xcode projects in the readable JSON format (Xcode 27+).
- Replace the project-specific source linter with pinned SwiftLint; retain Apple’s swift-format.
- Use typed, cancellable scheduled actions and monotonic timing; obsolete minimum/grace requests no longer affect a new presentation.
- Give presentation phases and completion delivery a dedicated owner; ignore stale animation completions and duplicate hides after completion.
- Observe Progress while presented in a window instead of polling by display link; stop on hide/detach and release removed HUDs.
- Apply configured container-appearance colors to indicators instead of leaving factory defaults.
- Preserve direct content colors when modes change; apply bulk color defaults only to newly created indicators unless contentColor is explicitly changed.
- Respect overridden getters in indicator drawing, bulk color application and Progress observation; retain open classes and Objective-C/KVO integration.
- Use typed indicator updates and add TMProgressHudProgressReporting for Swift custom views; retain legacy custom progress setters.
- Restore pie drawing when reusing a ring indicator.
- Make mode, animation and background-style values Sendable for checked transfer between Swift tasks.
- Keep enabled motion effects across repeated presentations and preserve effects added by the caller.
- Avoid a transient blur view for the solid HUD background and reuse the effect view when its blur material changes.
- Use native CGFloat precision for circular angles and documented opacity values instead of preserving C float promotion.
- Prevent duplicate owned backgrounds and blur effects when decoding views; retain caller-added subviews and document restoration with current defaults.
- Run GitHub Actions only when manually requested.

## 1.0.0

- Initial Swift 6 port of MBProgressHUD for iOS 15+ and tvOS 15+.
- Activity, pie, ring, bar, custom view and text modes; labels, action button, timing, animations and Foundation.Progress support.
- Swift Package Manager, CocoaPods, XCFramework and Carthage integration.
- XCFramework signed with a self-issued certificate, with a published certificate fingerprint and archive checksum.
- UIKit example app, API documentation, reference-comparison tests and coverage checks.
