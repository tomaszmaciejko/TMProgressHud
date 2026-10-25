# ``TMProgressHudUIKit``

Present progress and status using native Swift and UIKit on iOS and tvOS.

## Overview

All HUD presentation APIs are main-actor isolated. Supply the view that owns presentation; the library does not choose an application window or own your asynchronous operation.

```swift
let hud = TMProgressHud.showAdded(to: view, animated: true)
hud.label.text = "Loading"
hud.mode = .annularDeterminate
hud.progress = 0.5
// When the caller's operation completes:
hud.hide(animated: true)
```

The convenience helper removes the HUD on hide. To configure grace time, create a HUD with `init(view:)`, set timing properties, attach it and then show it.

Version 1.0 retains reference defaults and behaviors. Progress is not clamped; repeated hides can invoke repeated callbacks; timing follows the reference wall clock; ring-to-pie reuse retains the annular flag. Call hide to end progress polling rather than relying on removal alone. The caller can customize the exposed labels and custom UIView content.

## Topics

### Presentation

- ``TMProgressHud``
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
