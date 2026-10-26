# Compatibility and limitations

The unreleased TMProgressHud 2.0 development line builds on the Swift port of MBProgressHUD at revision `4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781`. It targets UIKit on iOS/iPadOS 17+ and tvOS 17+, with Swift 6.0+. Mac Catalyst, native macOS, watchOS and visionOS are not supported.

The published `v1.0.0` and maintenance branch `release/1.x` retain iOS/iPadOS 15+ support.

## Behavior

- Progress values are stored and forwarded without clamping. Built-in indicator drawings bound finite values to 0...1 and draw nonfinite values as zero. Circles fit the smaller bounds dimension and are centered; dimensions of 4 points or less draw nothing. The bar uses rounded paths with a proportionally clipped interior, including at very small progress; undersized bounds omit paths that cannot fit. This replaces the 1.x cap geometry and may change edge pixels. These are intentional 2.0 rendering changes.
- Indicator drawing restores the caller’s graphics state; the legacy circular renderer changed fill/stroke settings and blend mode. The pie selection retains the original outlined circular appearance.
- Round-style and bar-border color changes request redraw; equal values do not add redraw work.
- Version 2.0 uses native CGFloat precision for circular angles and opacity constants; it does not preserve C float-promotion artifacts. A few antialiasing samples at enlarged sizes may differ from 1.x.
- Enabled tilt effects remain installed across repeated presentations. Disabling them removes only the HUD-owned group.
- Per-request hide completion, compatibility completionBlock and delegate callbacks occur in that order after hiding. The compatibility callback is cleared before delivery. A per-request completion is discarded by a superseding show; repeated minimum-duration hides keep the first request's completion. Delegate notification uses the recipient selected before callbacks run. Repeated hide calls after completion do nothing; a new show cancels unfinished hiding and its callback. Re-showing visible content skips the grace delay.
- Switching between pie and ring updates the reused indicator in both directions.
- Grace and delayed hide use cancellable, main-actor actions and a monotonic clock. Replacing a pending action cancels the old one. Progress uses KVO while the HUD is presented in a window, with buffered delivery to the main actor. Hiding, detaching or replacing the source ends the previous observation; showing reads the latest value.
- Default text scales with Dynamic Type from the reference base sizes. Customize the exposed labels for your app's typography; set adjustsFontForContentSizeCategory to false when intentionally using a fixed font.
- The action button has zero intrinsic size until it has both a title and a registered event. Registering or removing actions invalidates that size, including after the HUD has been laid out. Its border and highlight use the active title color, including UIKit fallback when a state color is removed; configuring an inactive state does not recolor the active border.

On tvOS the background uses `.regular` blur; iOS uses `.systemThickMaterial`. The caller manages focus; see the tvOS example.

On both platforms the HUD follows its host size through UIKit autoresizing and synchronizes its frame when attached or reparented. Version 2.0 no longer observes global status-bar orientation notifications. Layout updates preserve constraints added by the caller.

## Complete selections in 2.0

Use `setContent(.custom(view))` to select custom content in one call, or `.activity`, `.pie`, `.ring`, `.bar` and `.text` for built-in content. Compatibility mode/customView getters reflect the completed selection. Non-custom selections clear the retained custom view. The old independent setters preserve their existing behavior.

Use `setProgressSource(.manual(value))` to stop observation before assigning a value, or `.observed(progress)` to select Foundation Progress. The compatibility progress/progressObject setters remain available; their independent use can still combine manual updates with observation.

## Explicit layout in 2.0

Use `setLayout(_:)` with `TMProgressHudLayout` to select position, contentInsets and hostInsets together. Position axes use left/center/right and top/center/bottom; offsets move right and down. Insets use physical edges and do not mirror with language. Positions refer to host bounds, with outer insets taking priority over an offset; safe areas are not applied implicitly. Minimum size and square preference remain separate properties.

The compatibility offset getter projects edge positions to `TMProgressMaxOffset` extremes; its setter changes only position. The margin getter reads the top content inset; assigning margin restores uniform inner and outer spacing. Use layoutConfiguration to read the full selection. Existing getter overrides remain effective, and compatibility KVO observers receive the completed selection.

## Explicit colors in 2.0

`defaultIndicatorColor` changes the default for future indicators without touching current views. `applyContentColor(_:)` recolors labels, the normal button title and the current indicator without changing that default; repeated calls apply again. Explicit indicator coloring bypasses the compatibility appearance-proxy lookup. Circular remaining-area alpha multiplies the supplied color's alpha and follows its dynamic appearance.

The compatibility `contentColor` property retains its earlier combined behavior described below.

## Motion in 2.0

`motionPolicy` defaults to `.system`, following Reduce Motion. `.reduced` uses fade instead of zoom and suppresses HUD-owned tilt effects; `.full` explicitly allows the selected motion. Changes affect future transitions and current owned tilt effects. Effects added by the caller and the requested areDefaultMotionEffectsEnabled value are preserved. Passing animated: false still disables the transition.

## Accessible progress in 2.0

Built-in pie, ring and bar views expose a localized percentage as their accessibility value. Finite values are bounded to 0...100 percent for this description only; raw progress remains unchanged. Nonfinite values have no numeric description. No per-update announcements are posted.

Set accessibilityLanguage, accessibilityLabel or an application-specific accessibilityValue when needed. Setting accessibilityValue back to nil restores the automatic percentage. Custom content keeps its own accessibility semantics; adopting the progress protocol does not replace its label, value or traits. Actual VoiceOver interaction remains a separate manual check.

## Background accessibility in 2.0

Blur backgrounds follow Reduce Transparency through `blurPolicy = .system`. Use `.opaque` to always replace blur with `opaqueBackgroundColor`, rendered at full alpha, or `.configured` to keep the requested material and tint under UIKit’s own behavior. Solid backgrounds are unaffected. Changing the policy preserves the requested color, material and caller-added content.

The default opaque surface adapts to light/dark appearance. Customize it together with text colors when branding; the default-palette contrast check does not qualify arbitrary custom colors or blurred content.

## Configuration

The exposed views are the source of truth for text, fonts and individual colors. Mode changes preserve existing view customizations; a newly created indicator inherits `contentColor`. Setting a different non-nil `contentColor` explicitly recolors current content. Setting the same value does nothing.

`contentColor = nil` stops bulk coloring and preserves existing colors. `.clear` is an explicit transparent color. Indicator colors resolve from container UIAppearance first, then `contentColor`, then the view default. Unlike the original port, a configured appearance color is explicitly applied rather than merely suppressing the bulk color. Set per-instance properties on the exposed views when you need local customization. Background `color = nil` clears its tint and keeps the blur.

## Swift API

The module is `TMProgressHudUIKit`. Original `MB` type prefixes become `TM`; the main class is spelled `TMProgressHud`. UIKit-facing APIs and delegate callbacks are main-actor isolated.

Common calls retain the Swift-imported spelling: `showAdded(to:animated:)`, `hide(for:animated:)`, `forView(_:)`, `show(animated:)` and `hide(animated:afterDelay:)`. Boolean properties include `isSquare`, `areDefaultMotionEffectsEnabled` and `isAnnular`.

Subclass frame initializers must be `required init(frame:)`. Native Swift enums reject unknown raw values. Nullable custom content and background colors follow the header contract without reproducing Objective-C debug assertion traps.

Objective-C selectors and dynamic progress setters are preserved. Swift does not export the offset constant or completion typealias as C globals/typedefs; Objective-C callers use an inline block type and their own offset value.

## Subclassing

The existing open UIKit API remains available for compatibility. New selection/color methods and per-request hide completion are closed facade operations. Prefer custom UIView composition and TMProgressHudProgressReporting for new integrations.

Open indicator color/style getters are used by drawing. HUD color application and progress observation also read the public getters, so an override is reflected in the result. This deliberately differs from the original implementation's direct reads of private drawing fields.

Return stable child-view and progress-source instances between configuration changes. Forward overridden setters to `super` to preserve updates, and request `setNeedsDisplay()` when a computed drawing value changes independently of a setter. Existing Objective-C selectors, KVC keys and progress KVO remain supported.

## Verification limits

The 1.0 release was checked with Swift 6.0.3 and the current CI toolchain, with a six-mode/action consumer check on iOS 15.5 and full hosted tests on newer simulators. Those results describe 1.0, not qualification of the unreleased 2.0 line.

Execution on the new minimum iOS 17.0 or tvOS 17.0, physical Apple TV remote input and an actual VoiceOver session remain unverified. The full supported-toolchain matrix is checked separately before release.

## Custom progress views

Use `setContent(.custom(view))` with `TMProgressHudProgressReporting` for typed, unnormalized progress. Native round/bar/spinner views and UIProgressView are recognized directly. Other custom views receive no automatic progress updates.

Use `setContent(.legacyCustom(view))` to opt into the Objective-C compatibility adapter. Its numeric `setProgress:` must be KVC-compliant and accept Float-compatible values; the selector alone cannot establish that contract. Typed support takes precedence. The old customView/mode setters retain automatic legacy detection. Switching between custom and legacyCustom for the same view changes forwarding without replacing the view.

## View decoding

`init(coder:)` restores a usable UIKit view with current library defaults. HUD text, styling, progress sources, presentation state and callbacks are not a saved-session format; configure them again in the app. Owned backgrounds and effects are reconstructed or reused without duplicating them, while caller-added subviews remain. Archives are not a versioned persistence format across library releases.
