# Changelog

## 2.0.0 (Unreleased)

### Requirements and API

- Require iOS/iPadOS 17+ and tvOS 17+, with Swift 6.0+. Bundled JSON Xcode projects require Xcode 27+.
- Add complete content, progress-source and layout selections, including content readback, while retaining compatibility properties. Name the outlined circular selection `outlinedCircle`.
- Add typed custom progress and explicit `updateProgress` functions for third-party views; remove automatic Objective-C progress setter discovery. Separate future/current color operations and add one-shot hide completions.

### Behavior and accessibility

- Reserve accessible `100%` for finite progress of at least `1`; retain whole-percent rounding below completion. Treat blank accessibility languages like an unset language.
- Honor custom progress protocols on activity-indicator subclasses and keep newer content selections made during custom-view configuration, attachment, removal or coloring.

- Make presentation callbacks single-use, reject obsolete work, use monotonic timing and stop observing Progress when hidden or detached.
- Preserve client constraints and customizations, keep caller-provided indicators separate from built-ins, and collapse hidden content.
- Follow Dynamic Type, Reduce Motion and Reduce Transparency; expose localized progress values. Wrap status text and support attributed, image, state-specific and configuration-based action content.
- Correct resize/redraw, circular geometry, bar fill, graphics-state restoration, active-state colors, reusable animations/spinners and motion effects. Progress drawings now bound invalid or out-of-range display values.
- Reconstruct one owned hierarchy when decoding, without restoring presentation state.

### Integration and maintenance

- Fix SwiftPM resource-bundle signing. Extend the UIKit example with adaptive safe areas, accessibility policy and application-owned operations.
- Give layout, presentation, scheduling, progress binding and indicators explicit owners. Use pinned SwiftLint with Apple's swift-format; run GitHub Actions only when requested manually.

See [migration notes](Docs/COMPATIBILITY.md) for behavior changes and remaining verification limits.

## 1.0.0

- Initial Swift 6 port of MBProgressHUD for iOS 15+ and tvOS 15+.
- Activity, pie, ring, bar, custom view and text modes; labels, action button, timing, animations and Foundation.Progress support.
- Swift Package Manager, CocoaPods, XCFramework and Carthage integration.
- XCFramework signed with a self-issued certificate, with a published certificate fingerprint and archive checksum.
- UIKit example app, API documentation, reference-comparison tests and coverage checks.
