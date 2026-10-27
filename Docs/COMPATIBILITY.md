# Migrating from 1.0 to 2.0

Version 2.0 is unreleased and requires iOS/iPadOS 17+ or tvOS 17+, with Swift 6.0+. The module remains `TMProgressHudUIKit`. Existing properties and Objective-C selectors remain available; adopt the new Swift selections gradually.

For the faithful iOS/tvOS 15 port, use [v1.0.0](https://github.com/tomaszmaciejko/TMProgressHud/tree/v1.0.0) and its versioned documentation. Mac Catalyst, native macOS, watchOS and visionOS are not supported.

## Prefer complete selections

| Existing configuration | New Swift API |
| --- | --- |
| `mode` and `customView` | `setContent(.ring)`, `.outlinedCircle`, `.bar`, `.activity`, `.text` or `.custom(view)` |
| `progress` and `progressObject` | `setProgressSource(.manual(value))` or `.observed(progress)` |
| `offset` and `margin` | `setLayout(_:)` with position and independent content/host insets |
| `completionBlock` | `hide(animated:completion:)` for a one-shot request |
| Combined `contentColor` | `defaultIndicatorColor` for future indicators; `applyContentColor(_:)` for current views |

Read `contentConfiguration` or `layoutConfiguration` to save and restore those selections. Content readback is nil for compatibility custom mode without a view. Text, progress and individual view styling remain independent.

Custom Swift progress views adopt `TMProgressHudProgressReporting`; native round/bar views and `UIProgressView` are recognized directly. Adapt other views with `.custom(view, updateProgress: { view.progress = Double($0) })`, using the setter and conversion your view needs. The function runs synchronously on the main actor and takes precedence over protocol/native forwarding. Automatic Objective-C `setProgress:` discovery and the unreleased `.legacyCustom` case are removed, including discovery through `customView`/`mode`.

Content readback retains the function with its view. Selecting an explicit function reapplies current progress even for the same view; selecting `.custom(view)` removes it. Compatibility mode changes retain inactive custom content and its function; assigning a different `customView` clears the old function. The HUD retains custom content, so capture an owner weakly if it also owns the HUD. The unreleased content name `.pie` became `.outlinedCircle`; compatibility mode `.determinate` is unchanged.

## Intentional behavior changes

- **Content and layout:** complete selections detach custom views before using built-in content. Hidden rows collapse and restore without removing client constraints. Existing getter overrides remain effective. Position and insets use physical host edges, without automatic safe-area adjustment or RTL mirroring.
- **Text and accessibility:** both labels wrap and default fonts follow Dynamic Type. Default action titles truncate at the tail. Reduce Motion and Reduce Transparency are followed by default; their policies are configurable. Round/bar indicators expose localized percentages. The application owns modal scope, focus and final announcements.
- **Progress and drawing:** raw progress is unchanged and forwarded without clamping. Built-in drawings bound finite values to 0...1 and display nonfinite values as zero; nonfinite progress has no spoken percentage. Circular drawings fit rectangular bounds, and bar rendering uses proportional fill. Edge pixels can differ from 1.0. `.outlinedCircle` is an outline and arc, not a filled pie wedge.
- **Presentation:** callbacks run once per completed presentation, in the order request completion → compatibility completionBlock → delegate. The compatibility callback is consumed. Re-showing supersedes unfinished hiding and its completion; repeated minimum-duration hides retain the first request completion. Re-showing visible content skips grace time.
- **Timing and ownership:** grace, minimum-visible time and delayed hide use cancellable monotonic scheduling. Replacing a request invalidates old work. Foundation Progress is observed only while presented in a window; hiding or detaching stops observation, and showing refreshes its value.
- **Styling:** direct view customizations survive compatible transitions. Explicit coloring bypasses the appearance proxy; compatibility bulk coloring still respects it. Nil bulk color preserves current colors; background color nil clears the requested tint. Caller-provided UIButton configurations own their appearance and insets.
- **Decoding:** view archives reconstruct usable views with current defaults and preserve caller subviews. They do not save operation state, callbacks or HUD configuration, and are not a versioned persistence format.

For precise callback, input-range, layout and styling contracts, see the public symbol documentation and [API guide](../Sources/TMProgressHudUIKit/TMProgressHudUIKit.docc/TMProgressHudUIKit.md). UIKit APIs and callbacks belong to the main actor. New facade selections use composition; the existing open API remains for compatibility.

## Verification limits

Exact iOS/tvOS 17 runtime execution and the oldest-supported-compiler qualification remain pending for 2.0. Automated simulator checks do not qualify physical Apple TV input or an actual VoiceOver session. The published 1.0 results do not qualify the 2.0 implementation.
