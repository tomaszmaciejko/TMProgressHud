# ``TMProgressHudUIKit``

Present progress and status using native Swift and UIKit on iOS and tvOS.

## Overview

All HUD presentation APIs are main-actor isolated. Supply the view that owns presentation; the library does not choose an application window or own your asynchronous operation.

```swift
let hud = TMProgressHud.showAdded(to: view, animated: true)
hud.label.text = "Loading"
hud.setContent(.ring)
hud.setProgressSource(.manual(0.5))
// When the caller's operation completes:
hud.hide(animated: true)
```

The convenience helper removes the HUD on hide. To configure grace time, create a HUD with `init(view:)`, set timing properties, attach it and then show it.

Progress values are forwarded without clamping. A new show supersedes unfinished hiding; completion and delegate callbacks run once per completed presentation. A Progress source is observed only while the HUD is presented in a window. The caller can customize the exposed labels and custom UIView content.

## Saving content and applying colors

Read `contentConfiguration` to restore an indicator after temporarily displaying another selection. It is nil only for compatibility custom mode without a view. Message text and progress are independent.

```swift
let previousContent = hud.contentConfiguration
hud.setContent(.text)
// Restore when appropriate:
if let previousContent { hud.setContent(previousContent) }
```

Set `defaultIndicatorColor` for future indicators and call `applyContentColor(_:)` to recolor current views. Individual view customizations remain available; there is no single color describing all customized content.

```swift
hud.defaultIndicatorColor = .systemBlue
hud.applyContentColor(.systemBlue)
```

## Position and spacing

Positions and insets use physical host edges; left/right do not mirror in RTL. The host bounds are the reference area, and minimum size and square preference remain separate.

For a bottom HUD, configure before attaching and showing it:

```swift
hud.setLayout(.init(position: .init(vertical: .bottom)))
```

In the host view controller, update outer insets when the safe area changes. Add spacing to the actual host's safe area, rather than using a fixed home-indicator height:

```swift
override func viewSafeAreaInsetsDidChange() {
    super.viewSafeAreaInsetsDidChange()
    guard let hud else { return }
    let safe = view.safeAreaInsets
    let spacing = TMProgressHudLayout.defaultInsets
    var layout = hud.layoutConfiguration
    layout.hostInsets = .init(
        top: safe.top + spacing.top, left: safe.left + spacing.left,
        bottom: safe.bottom + spacing.bottom, right: safe.right + spacing.right)
    hud.setLayout(layout)
}
```

Apply the same calculation when creating the HUD. The UIKit demo includes a bottom-placement example and handles changes through this callback. Use insets from the view hosting the HUD, not an unrelated application window.

## System progress bar

Use UIKit's system appearance through custom content. The HUD forwards progress to the view; an explicit width lets Auto Layout size the bar.

```swift
let progressView = UIProgressView(progressViewStyle: .default)
progressView.widthAnchor.constraint(equalToConstant: 120).isActive = true
hud.setContent(.custom(progressView))
hud.setProgressSource(.manual(0.5))
```

## Custom progress functions

For your own views, adopt ``TMProgressHudProgressReporting``. To integrate a view without changing its type, pass a function using its own update API:

```swift
let progressView = UIProgressView(progressViewStyle: .default)
progressView.widthAnchor.constraint(equalToConstant: 120).isActive = true
hud.setContent(.custom(progressView, updateProgress: {
    progressView.setProgress($0, animated: true)
}))
```

The function runs synchronously on the main actor, receives raw progress and overrides protocol/native forwarding. Selecting it always forwards current progress, including when replacing a function on the same view. `.custom(view)` restores typed forwarding. No setter is discovered by name. Saved content retains its function; the HUD releases it when that custom content is replaced. Capture a controller weakly if it also owns the HUD.

## Accessible presentations

The application chooses accessibility modal scope, focus movement and final-result announcements. Touch blocking and VoiceOver modal scope are independent: a visible HUD handles touches by default, even with a clear background. Setting `isUserInteractionEnabled = false` disables its touch handling, including the action button.

For blocking operations, opt into `accessibilityViewIsModal`. Post a screen-change notification when the HUD is visible, and restore the initiating control after the per-request hide completion. The UIKit example owns this policy: with VoiceOver running it uses zero-grace, nonanimated presentation and [`AccessibilityNotification.ScreenChanged`](https://developer.apple.com/documentation/accessibility/accessibilitynotification/screenchanged), available from iOS/tvOS 17. The library does not move focus automatically.

Built-in progress views expose percentages without posting per-update announcements. Announce a meaningful final result once at the application level. Custom content retains its own accessibility labels, values and traits. An actual VoiceOver session remains a separate manual qualification step.

## Owning an operation

Keep the Task in your view controller. Wire Cancel to that task, and use `defer` to hide the HUD on success, error or cancellation. Handle cancellation separately from failure; a weak controller capture and per-request HUD ownership prevent old cleanup from hiding a newer presentation.

The UIKit example contains a complete implementation and automated checks for all three outcomes. It also cancels work when the controller disappears. The HUD never starts or cancels the application's operation itself.

## Topics

### Presentation

- ``TMProgressHud``
- ``TMProgressHudContent``
- ``TMProgressHudProgressSource``
- ``TMProgressHudMode``
- ``TMProgressHudAnimation``
- ``TMProgressHudMotionPolicy``
- ``TMProgressHudDelegate``
- ``TMProgressHudCompletionBlock``
- ``TMProgressMaxOffset``

### Layout

- ``TMProgressHudLayout``
- ``TMProgressHudPosition``

### Content views

- ``TMRoundProgressView``
- ``TMBarProgressView``
- ``TMBackgroundView``
- ``TMProgressHudBackgroundStyle``
- ``TMProgressHudBlurPolicy``
- ``TMProgressHudProgressReporting``
