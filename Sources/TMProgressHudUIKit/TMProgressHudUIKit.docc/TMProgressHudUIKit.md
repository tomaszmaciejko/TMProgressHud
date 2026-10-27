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

Select physical edges without numeric offsets. Insets refer to the host bounds; minimum size and square preference remain separate.

```swift
hud.setLayout(.init(
    position: .init(vertical: .bottom),
    contentInsets: .init(top: 12, left: 16, bottom: 12, right: 16),
    hostInsets: .init(top: 24, left: 24, bottom: 40, right: 24)))
```

## System progress bar

Use UIKit's system appearance through custom content. The HUD forwards progress to the view; an explicit width lets Auto Layout size the bar.

```swift
let progressView = UIProgressView(progressViewStyle: .default)
progressView.widthAnchor.constraint(equalToConstant: 120).isActive = true
hud.setContent(.custom(progressView))
hud.setProgressSource(.manual(0.5))
```

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
