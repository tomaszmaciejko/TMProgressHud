# Changelog

## 2.0.0 (Unreleased)

- Show adaptive safe-area placement in the UIKit example.

- Read and restore the selected indicator through contentConfiguration, including typed or legacy custom forwarding.

- Name the new circular content selection outlinedCircle to match its outline-and-arc appearance.

- Wrap primary status messages at large text sizes and define tail truncation for default action titles.

- Collapse hidden content without changing caller-owned constraints, restoring its layout when shown.

- Support attributed, image and state-specific action content; respect caller-provided UIButton configurations.

- Keep caller-provided custom indicators separate from built-in content in the new selection API.

- Update an already displayed action button and its spacing when actions are registered or removed.

- Restore caller graphics state after drawing circular indicators.

- Make custom content use typed progress by default; add explicit legacyCustom opt-in while keeping old property behavior.

- Add explicit position and independent content/host insets, retaining compatibility layout properties and atomic KVO.

- Simplify bar rendering to rounded paths and a proportional interior fill, including safe small-size and nonfinite-input behavior.

- Fit circular indicators within rectangular bounds and safely bound their displayed progress.

- Redraw built-in indicators after resizing instead of stretching a cached drawing.

- Follow Reduce Transparency with an adaptive opaque background and explicit per-background policy.

- Expose localized accessible progress values while preserving application overrides and raw input values.

- Follow Reduce Motion for zoom and HUD-owned tilt effects, with an explicit per-HUD policy.

- Scale default labels and action-button typography with Dynamic Type.

- Keep new facade operations closed to overriding while preserving existing subclassing hooks for compatibility.

- Separate future indicator colors from explicit recoloring; explicit circular tinting preserves dynamic alpha and transparency.

- Add complete content selections and explicit manual/observed progress sources while retaining compatibility properties.

- Add one-shot per-request hide completions; consume compatibility callbacks and snapshot delegates before delivery.

- Derive action-button borders and highlights from the active UIKit title color instead of setter order.

- Draw horizontal bars consistently during partial updates and with shifted bounds.

- Start a reused custom spinner when switching to indeterminate mode.

- Restore normal HUD geometry when showing without animation after a zoom dismissal.

- Require iOS 17+ and tvOS 17+. Package installation still supports Swift 6.0+; editing the bundled JSON Xcode projects requires Xcode 27+.
- Give layout, presentation phases, scheduled actions, Progress observation and indicator updates explicit owners. Use monotonic timing and observe Progress only while presented in a window.
- Ignore obsolete timing and animation completions; deliver completion callbacks once per presentation. Release detached HUDs instead of retaining them through progress polling.
- Preserve app-added constraints, direct content colors and enabled motion effects across mode or presentation changes. Apply container-appearance colors correctly and respect overridden getters.
- Refresh drawing and button borders when appearance changes. Standalone round-style and bar-border changes request redraw; reused rings switch back to pie correctly.
- Use current UIKit spring animations, follow host resizing through layout, reuse blur effects and use native CGFloat precision. Enlarged circular drawings may have small antialiasing differences from 1.0.
- Prevent duplicate owned views during decoding. Decoded views use current defaults and retain caller-added subviews; active presentation state is not restored.
- Add `TMProgressHudProgressReporting` for Swift custom indicators and Sendable conformance for value enums. Retain legacy custom progress setters and Objective-C/KVO integration.
- Use pinned SwiftLint with Apple’s swift-format, simplify local project/distribution checks and run GitHub Actions only when manually requested.

## 1.0.0

- Initial Swift 6 port of MBProgressHUD for iOS 15+ and tvOS 15+.
- Activity, pie, ring, bar, custom view and text modes; labels, action button, timing, animations and Foundation.Progress support.
- Swift Package Manager, CocoaPods, XCFramework and Carthage integration.
- XCFramework signed with a self-issued certificate, with a published certificate fingerprint and archive checksum.
- UIKit example app, API documentation, reference-comparison tests and coverage checks.
