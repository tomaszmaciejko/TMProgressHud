# UIKit example

Open `UIKitDemo/TMProgressHudDemo.xcodeproj` in Xcode 27+, select `TMProgressHudDemo` and run on iOS 17+ or tvOS 17+. It uses the local Swift package.

Try the six modes, Close and bottom placement. The view controller updates outer spacing when its safe area changes; physical left/right positions do not mirror in RTL.

The operation examples demonstrate success, failure and cancellation. The application owns the Task, cancels it through the HUD action, and cleans up its own HUD in defer. Leaving the controller also cancels its task.

The example opts into accessibility modal scope and requests focus after showing/dismissing. With VoiceOver running, it uses the typed iOS/tvOS 17 notification API and presents without animation. Actual VoiceOver interaction and physical Apple TV focus remain unverified. The Objective-C test reference is not linked into the example.
