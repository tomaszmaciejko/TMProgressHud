# TMProgressHud

A Swift progress and status HUD for UIKit on iOS and tvOS, originally ported from [MBProgressHUD](https://github.com/jdg/MBProgressHUD/tree/4a7c5f3e53cdea77c5dcb8578c2ee5acacdf6781).

Display an activity indicator, pie, ring, horizontal bar, custom view or message, with an optional action button. You choose the host view and control the underlying operation.

**Development requirements:** iOS 17+ or tvOS 17+, Swift 6.0+. Mac Catalyst is not supported. This branch is preparing **2.0.0**, which has not been released. Editing the bundled JSON Xcode projects requires Xcode 27+; package installation retains Swift 6.0+ support.

The published [1.0.0](https://github.com/tomaszmaciejko/TMProgressHud/tree/v1.0.0) supports iOS 15+ and tvOS 15+.

## Installation

The instructions below install the published **1.0.0**. To try development version 2.0, add this checkout as a local Swift package in Xcode; it requires iOS 17+ or tvOS 17+.

All methods provide the **TMProgressHudUIKit** module. Choose one per app target.

### Swift Package Manager

Add `https://github.com/tomaszmaciejko/TMProgressHud.git` in Xcode, choose version **1.0.0** and select `TMProgressHudUIKit`. In a package manifest, add:

```swift
.package(url: "https://github.com/tomaszmaciejko/TMProgressHud.git", exact: "1.0.0")
```

Link the `TMProgressHudUIKit` product to your application target.

### CocoaPods

```ruby
platform :ios, '15.0' # Use :tvos for Apple TV.
use_frameworks!
pod 'TMProgressHudUIKit', :git => 'https://github.com/tomaszmaciejko/TMProgressHud.git', :tag => 'v1.0.0'
```

### XCFramework

Download `TMProgressHudUIKit.xcframework.zip` and `SHA256SUMS` from the matching [GitHub release](https://github.com/tomaszmaciejko/TMProgressHud/releases). In the download folder, run `shasum -a 256 -c SHA256SUMS`, then unpack and add the framework to your app with **Embed & Sign**. Keep its bundled privacy and license resources.

The XCFramework uses a self-issued signing certificate. Compare the certificate's SHA-256 fingerprint shown by Xcode with the [published fingerprint](Certificates/TMProgressHud-signing.fingerprint). The [public certificate](Certificates/TMProgressHud-signing.pem) is included for verification; you do not need to install it as a trusted system certificate.

### Carthage

```text
github "tomaszmaciejko/TMProgressHud" ~> 1.0
```

Run `carthage update --use-xcframeworks --platform iOS,tvOS` and add the resulting XCFramework with **Embed & Sign**.

## Usage

Call the API on the main actor:

```swift
import TMProgressHudUIKit

let hud = TMProgressHud.showAdded(to: view, animated: true)
hud.label.text = "Loading"
hud.detailsLabel.text = "Please wait."

// When your operation finishes:
hud.hide(animated: true)
```

In development version 2.0, use `hide(animated:completion:)` for a one-shot callback receiving the finished HUD; a superseding show cancels that request. Use the delegate for recurring dismissal notifications.

The helper attaches the HUD and removes it when hidden. Use `TMProgressHud(view:)` to configure it before attaching and showing it yourself.

```swift
hud.mode = .annularDeterminate
hud.progress = 0.5
// Alternatively: hud.progressObject = yourFoundationProgress

hud.button.setTitle("Cancel", for: .normal)
hud.button.addAction(UIAction { _ in
    // Cancel your operation and hide the HUD as appropriate.
}, for: .primaryActionTriggered)
```

Other modes: `.indeterminate`, `.determinate`, `.determinateHorizontalBar`, `.customView` and `.text`. Set `customView` to supply your own content. Labels, bezel and background are customizable.

On tvOS, direct focus to the HUD's action button in your own view controller. The [example app](Examples/README.md) shows how.

## Compatibility

Version 1.0 preserves the original behavior, including unclamped progress, fixed font sizes and repeated callbacks on repeated hides. See [compatibility notes](Docs/COMPATIBILITY.md) for these details and Swift API differences.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, tests and review guidelines. There are no third-party runtime dependencies.

## License

[MIT](LICENSE). Swift port maintained by Tomasz Maciejko and contributors.

Based on MBProgressHUD by Matej Bukovinski. Original copyright and permission notices are preserved in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The Objective-C reference is used only by tests.
