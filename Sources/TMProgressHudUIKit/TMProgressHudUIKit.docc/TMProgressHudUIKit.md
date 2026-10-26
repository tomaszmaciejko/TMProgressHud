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
- ``TMProgressHudDelegate``
- ``TMProgressHudCompletionBlock``
- ``TMProgressMaxOffset``

### Content views

- ``TMRoundProgressView``
- ``TMBarProgressView``
- ``TMBackgroundView``
- ``TMProgressHudBackgroundStyle``
- ``TMProgressHudProgressReporting``
