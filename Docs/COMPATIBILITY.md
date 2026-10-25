# Compatibility and limitations

The unreleased TMProgressHud 2.0 development line builds on the Swift port of MBProgressHUD at revision `4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781`. It targets UIKit on iOS/iPadOS 17+ and tvOS 17+, with Swift 6.0+. Mac Catalyst, native macOS, watchOS and visionOS are not supported.

The published `v1.0.0` and maintenance branch `release/1.x` retain iOS/iPadOS 15+ support.

## Preserved behavior

- Progress values are stored and forwarded without clamping.
- Repeated hide calls can repeat completion and delegate callbacks.
- Reusing a ring indicator as a pie retains its annular state.
- Timing uses wall time and the original timer/display-link ownership. Hide the HUD when work finishes; removing its host alone does not end pending work.
- Fonts have fixed reference sizes. Customize the exposed labels for your app's typography and accessibility needs.
- The action button has zero intrinsic size until it has both a title and a registered event.

On tvOS the background uses `.regular` blur; iOS uses `.systemThickMaterial`. The caller manages focus; see the tvOS example.

On both platforms the HUD follows its host size through UIKit autoresizing and synchronizes its frame when attached or reparented. Version 2.0 no longer observes global status-bar orientation notifications. Layout updates preserve constraints added by the caller.

## Swift API

The module is `TMProgressHudUIKit`. Original `MB` type prefixes become `TM`; the main class is spelled `TMProgressHud`. UIKit-facing APIs and delegate callbacks are main-actor isolated.

Common calls retain the Swift-imported spelling: `showAdded(to:animated:)`, `hide(for:animated:)`, `forView(_:)`, `show(animated:)` and `hide(animated:afterDelay:)`. Boolean properties include `isSquare`, `areDefaultMotionEffectsEnabled` and `isAnnular`.

Subclass frame initializers must be `required init(frame:)`. Native Swift enums reject unknown raw values. Nullable custom content and background colors follow the header contract without reproducing Objective-C debug assertion traps.

Objective-C selectors and dynamic progress setters are preserved. Swift does not export the offset constant or completion typealias as C globals/typedefs; Objective-C callers use an inline block type and their own offset value.

## Verification limits

The 1.0 release was checked with Swift 6.0.3 and the current CI toolchain, with a six-mode/action consumer check on iOS 15.5 and full hosted tests on newer simulators. Those results describe 1.0, not qualification of the unreleased 2.0 line.

Execution on the new minimum iOS 17.0 or tvOS 17.0, physical Apple TV remote input and an actual VoiceOver session remain unverified. The full supported-toolchain matrix is checked separately before release.
