# TMProgressHud

A Swift progress and status HUD for UIKit. Show activity, circular progress, a ring, a bar, a message or your own view, with an optional action button.

**This branch contains unreleased 2.0:** iOS/iPadOS 17+, tvOS 17+, Swift 6.0+. For the published version supporting iOS/tvOS 15, use the [1.0.0 documentation](https://github.com/tomaszmaciejko/TMProgressHud/tree/v1.0.0). Mac Catalyst is not supported.

## Try 2.0

All installation methods provide `TMProgressHudUIKit`. Choose one per app target. The examples below use the development API.

### Swift Package Manager

Add `https://github.com/tomaszmaciejko/TMProgressHud.git` in Xcode, select branch **main** and link `TMProgressHudUIKit`. In a package manifest:

```swift
.package(url: "https://github.com/tomaszmaciejko/TMProgressHud.git", branch: "main")
```

### CocoaPods

```ruby
platform :ios, '17.0' # Use :tvos for Apple TV.
use_frameworks!
pod 'TMProgressHudUIKit', :git => 'https://github.com/tomaszmaciejko/TMProgressHud.git', :branch => 'main'
```

### XCFramework

Build from this checkout into a fresh output folder:

```sh
TMHUD_ARTIFACT_DIR=.build/LocalFramework ./Scripts/build-xcframework.sh
```

Add the resulting framework to your app with **Embed & Sign**, keeping its privacy and license resources. Local builds are unsigned unless you explicitly configure signing. Published binaries and their verification files live in [GitHub releases](https://github.com/tomaszmaciejko/TMProgressHud/releases); use the documentation matching that release.

### Carthage

```text
github "tomaszmaciejko/TMProgressHud" "main"
```

Run `carthage update --use-xcframeworks --platform iOS,tvOS` and add the framework with **Embed & Sign**. Bundled JSON Xcode projects, including Carthage source builds, require **Xcode 27+**. SwiftPM and CocoaPods source installation retain the Swift 6.0 requirement.

## Usage

Call the API on the main actor, for example from a view controller:

```swift
import TMProgressHudUIKit

let hud = TMProgressHud.showAdded(to: view, animated: true)
hud.label.text = "Downloading"
hud.setContent(.ring)
hud.setProgressSource(.manual(0.5))

// When your operation finishes:
hud.hide(animated: true)
```

The helper removes the HUD when hidden. Use `TMProgressHud(view:)` to configure it before attaching and showing it yourself. Your application owns the operation and cancellation.

Use `.observed(progress)` for a Foundation `Progress`, and `.activity`, `.outlinedCircle`, `.bar`, `.text` or `.custom(view)` for other content. The [API guide](Sources/TMProgressHudUIKit/TMProgressHudUIKit.docc/TMProgressHudUIKit.md) covers layout, colors, custom progress and accessibility. Existing properties remain supported; see [migration from 1.0](Docs/COMPATIBILITY.md).

## Example and contributing

The [UIKit example](Examples/README.md) demonstrates every mode, safe-area placement and an application-owned task with success, failure and cancellation. There are no third-party runtime dependencies.

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and tests. Exact minimum-OS runtime checks, the oldest-compiler qualification, physical Apple TV input and a manual VoiceOver session remain separate verification steps for unreleased 2.0.

## License

[MIT](LICENSE). Swift port maintained by Tomasz Maciejko and contributors. Based on MBProgressHUD by Matej Bukovinski; original notices are preserved in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). The Objective-C reference is used only by tests.
